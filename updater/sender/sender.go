package sender

import (
	"crypto/ecdsa"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
)

type Sender struct {
	chainID    int64
	address    common.Address
	privateKey *ecdsa.PrivateKey
}

func NewSender(chainID int64, privateKey *ecdsa.PrivateKey) *Sender {
	address := crypto.PubkeyToAddress(privateKey.PublicKey)
	return &Sender{
		chainID:    chainID,
		address:    address,
		privateKey: privateKey,
	}
}

func (s *Sender) Address() common.Address {
	return s.address
}

func (s *Sender) SignerFn() bind.SignerFn {
	return func(address common.Address, tx *types.Transaction) (*types.Transaction, error) {
		signer := types.LatestSignerForChainID(big.NewInt(s.chainID))
		if address != s.address {
			return nil, errors.New("invalid sender address")
		}
		return types.SignTx(tx, signer, s.privateKey)
	}
}
