package main

import (
	"context"
	"drand-oracle-updater/binding"
	"drand-oracle-updater/config"
	"drand-oracle-updater/internal/service"
	"drand-oracle-updater/sender"
	"drand-oracle-updater/signer"
	"encoding/hex"
	"strings"

	"github.com/ethereum/go-ethereum/crypto"

	"github.com/drand/drand/client"
	"github.com/drand/drand/client/http"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/kelseyhightower/envconfig"
	"github.com/rs/zerolog/log"
	"golang.org/x/sync/errgroup"
)

func main() {
	var cfg config.Config
	if err := envconfig.Process("", &cfg); err != nil {
		log.Fatal().Err(err).Msg("Failed to process environment variables")
	}

	chainHash, err := hex.DecodeString(cfg.ChainHash)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to decode chain hash")
	}

	// Initialize drand client
	log.Info().
		Str("drand_urls", strings.Join(cfg.DrandURLs, ",")).
		Str("chain_hash", hex.EncodeToString(chainHash)).
		Msg("Initializing drand client...")
	drandClient, err := client.New(
		client.From(http.ForURLs(cfg.DrandURLs, chainHash)...),
		client.WithChainHash(chainHash),
	)
	if err != nil {
		log.Fatal().Err(err).Msg("error creating client")
	}

	// Initialize RPC client
	log.Info().Str("rpc_url", cfg.RPC).Msg("Initializing RPC client...")
	rpcClient, err := ethclient.Dial(cfg.RPC)
	if err != nil {
		log.Fatal().Err(err).Msg("error creating rpc client")
	}

	// Initialize contract binding
	log.Info().Str("address", cfg.DrandOracleAddress).Msg("Initializing DrandOraclecontract binding...")
	binding, err := binding.NewBinding(common.HexToAddress(cfg.DrandOracleAddress), rpcClient)
	if err != nil {
		log.Fatal().Err(err).Msg("error creating binding")
	}

	// Initialize signer
	log.Info().Int64("chain_id", cfg.ChainID).Msg("Initializing signer...")
	signerPrivateKey, err := crypto.HexToECDSA(strings.TrimPrefix(cfg.SignerPrivateKey, "0x"))
	if err != nil {
		log.Fatal().Err(err).Msg("error parsing private key")
	}
	signer := signer.NewSigner(cfg.ChainID, common.HexToAddress(cfg.DrandOracleAddress), signerPrivateKey)
	log.Info().Str("address", signer.Address().Hex()).Msg("Signer initialized")

	// Initialize sender
	log.Info().Int64("chain_id", cfg.ChainID).Msg("Initializing sender...")
	senderPrivateKey, err := crypto.HexToECDSA(strings.TrimPrefix(cfg.SenderPrivateKey, "0x"))
	if err != nil {
		log.Fatal().Err(err).Msg("error parsing private key")
	}
	sender := sender.NewSender(cfg.ChainID, senderPrivateKey)
	log.Info().Str("address", sender.Address().Hex()).Msg("Sender initialized")

	// Initialize updater service
	log.Info().Msg("Initializing updater service...")
	updater, err := service.NewUpdater(drandClient, rpcClient, binding, cfg.GenesisRound, signer, sender)
	if err != nil {
		log.Fatal().Err(err).Msg("error creating updater")
	}

	// Start all services
	log.Info().Msg("Starting services...")
	errGroup, ctx := errgroup.WithContext(context.Background())
	errGroup.Go(func() error {
		if err := updater.Start(ctx); err != nil {
			return err
		}
		return nil
	})

	if err := errGroup.Wait(); err != nil {
		log.Fatal().Err(err).Msg("service error")
	}
}
