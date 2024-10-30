package service

import (
	"context"
	"drand-oracle-updater/binding"
	"drand-oracle-updater/sender"
	"drand-oracle-updater/signer"
	"encoding/hex"
	"errors"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"

	"github.com/drand/drand/client"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/rs/zerolog/log"
	"golang.org/x/sync/errgroup"
)

type Updater struct {
	// drandClient is the Drand HTTP client
	drandClient client.Client

	// rpcClient is the Ethereum RPC client
	rpcClient *ethclient.Client

	// binding is the Drand Oracle contract binding
	binding *binding.Binding

	// genesisRound is the round at which oracle starts tracking
	genesisRound uint64

	// roundChan is the channel for processing rounds
	roundChan chan *roundData

	// latestOracleRound keeps track of the latest round processed by the Oracle
	latestOracleRound      uint64
	latestOracleRoundMutex sync.RWMutex

	// latestDrandRound keeps track of the latest round from the Drand network
	latestDrandRound      uint64
	latestDrandRoundMutex sync.RWMutex

	// signer is the signer for the Drand Oracle contract
	signer *signer.Signer

	// sender is the sender for the Drand Oracle contract
	sender *sender.Sender
}

type roundData struct {
	round      uint64
	randomness []byte
	signature  []byte
}

func NewUpdater(
	drandClient client.Client,
	rpcClient *ethclient.Client,
	binding *binding.Binding,
	genesisRound uint64,
	signer *signer.Signer,
	sender *sender.Sender,
) (*Updater, error) {
	return &Updater{
		drandClient:       drandClient,
		rpcClient:         rpcClient,
		binding:           binding,
		genesisRound:      genesisRound,
		roundChan:         make(chan *roundData, 1),
		latestOracleRound: 0,
		latestDrandRound:  0,
		signer:            signer,
		sender:            sender,
	}, nil
}

func (u *Updater) Start(ctx context.Context) error {
	// Get the earliest and latest round from the Drand Oracle contract
	earliestRound, err := u.binding.EarliestRound(nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get earliest round from Drand Oracle contract")
		return err
	}
	latestRound, err := u.binding.LatestRound(nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get latest round from Drand Oracle contract")
		return err
	}
	u.latestOracleRoundMutex.Lock()
	u.latestOracleRound = latestRound
	u.latestOracleRoundMutex.Unlock()
	log.Info().Msgf("Oracle: Earliest round: %d, Latest round: %d", earliestRound, latestRound)

	// Get the latest round from the Drand network
	latestDrandRound, err := u.drandClient.Get(ctx, 0)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get latest round from Drand network")
		return err
	}
	u.latestDrandRoundMutex.Lock()
	u.latestDrandRound = latestDrandRound.Round()
	u.latestDrandRoundMutex.Unlock()
	log.Info().Msgf("Drand: Latest round: %d", u.latestDrandRound)

	errg, ctx := errgroup.WithContext(ctx)
	errg.Go(func() error {
		return u.processRounds(ctx)
	})
	errg.Go(func() error {
		return u.catchUp(ctx)
	})
	errg.Go(func() error {
		return u.watchNewRounds(ctx)
	})
	return errg.Wait()
}

func (u *Updater) catchUp(ctx context.Context) error {
	for {
		u.latestDrandRoundMutex.RLock()
		latestDrandRound := u.latestDrandRound
		u.latestDrandRoundMutex.RUnlock()

		u.latestOracleRoundMutex.RLock()
		latestOracleRound := u.latestOracleRound
		u.latestOracleRoundMutex.RUnlock()

		if latestDrandRound == latestOracleRound+1 {
			break
		}

		var currentRound uint64
		if latestOracleRound == 0 {
			currentRound = u.genesisRound
		} else {
			currentRound = latestOracleRound + 1
		}

		for currentRound <= latestDrandRound {
			result, err := u.drandClient.Get(ctx, currentRound)
			if err != nil {
				log.Error().Err(err).Uint64("round", currentRound).Msg("Failed to get round from Drand network")
				return err
			}

			u.roundChan <- &roundData{
				round:      result.Round(),
				randomness: result.Randomness(),
				signature:  result.Signature(),
			}
			currentRound++
		}
	}
	return nil
}

func (u *Updater) watchNewRounds(ctx context.Context) error {
	for result := range u.drandClient.Watch(ctx) {
		log.Info().Msgf("Drand: New round: %d", result.Round())
		u.roundChan <- &roundData{
			round:      result.Round(),
			randomness: result.Randomness(),
			signature:  result.Signature(),
		}
	}
	return nil
}

func (u *Updater) processRounds(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case rd := <-u.roundChan:
			if err := u.processRound(ctx, rd.round, rd.randomness, rd.signature); err != nil {
				log.Error().Err(err).Uint64("round", rd.round).Msg("Failed to process round")
				return err
			}
		}
	}
}

func (u *Updater) processRound(
	ctx context.Context,
	round uint64,
	randomness []byte,
	signature []byte,
) error {
	u.latestOracleRoundMutex.Lock()
	defer u.latestOracleRoundMutex.Unlock()
	if round != u.genesisRound && u.latestOracleRound+1 != round {
		log.Info().
			Uint64("latestOracleRound", u.latestOracleRound).
			Uint64("round", round).
			Msg("Skipping round, not caught up yet")
		return nil
	}

	log.Info().
		Uint64("round", round).
		Str("randomness", hex.EncodeToString(randomness)).
		Str("signature", hex.EncodeToString(signature)).
		Msg("Processing round")

	eip712Signature, err := u.signer.SignSetRandomness(round, [32]byte(randomness), signature)
	if err != nil {
		log.Error().Err(err).Msg("Failed to sign set randomness")
		return err
	}

	tx, err := u.binding.SetRandomness(
		&bind.TransactOpts{
			From:     u.sender.Address(),
			Signer:   u.sender.SignerFn(),
			GasLimit: 1000000,                // TODO: estimate gas
			GasPrice: big.NewInt(1000000000), // TODO: estimate gas price
		},
		binding.IDrandOracleRandom{
			Round:      round,
			Randomness: [32]byte(randomness),
			Signature:  signature,
		},
		eip712Signature,
	)
	if err != nil {
		return err
	}
	receipt, err := bind.WaitMined(ctx, u.rpcClient, tx)
	if err != nil {
		log.Error().Err(err).Msg("Failed to wait for transaction to be mined")
		return err
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		err = errors.New("set randomness transaction failed")
		return err
	} else {
		log.Info().Uint64("round", round).Str("hash", tx.Hash().Hex()).Msg("Set randomness transaction successful")
		u.latestOracleRound = round
	}
	return nil
}

// Add a getter method for safe access
func (u *Updater) GetLatestOracleRound() uint64 {
	u.latestOracleRoundMutex.RLock()
	defer u.latestOracleRoundMutex.RUnlock()
	return u.latestOracleRound
}
