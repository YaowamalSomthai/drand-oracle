package signer

import (
	"crypto/ecdsa"
	"fmt"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/common/math"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/signer/core/apitypes"
)

type Signer struct {
	chainID            int64
	drandOracleAddress common.Address
	privateKey         *ecdsa.PrivateKey
}

func NewSigner(
	chainID int64,
	drandOracleAddress common.Address,
	privateKey *ecdsa.PrivateKey,
) *Signer {
	return &Signer{
		chainID:            chainID,
		drandOracleAddress: drandOracleAddress,
		privateKey:         privateKey,
	}
}

func (s *Signer) Address() common.Address {
	return crypto.PubkeyToAddress(s.privateKey.PublicKey)
}

func (s *Signer) SignSetRandomness(round uint64, randomness [32]byte, signature []byte) ([]byte, error) {
	typeData := &apitypes.TypedData{
		Types: apitypes.Types{
			// SetRandomness(uint64 round,bytes32 randomness,bytes signature)
			"SetRandomness": []apitypes.Type{
				{Name: "round", Type: "uint64"},
				{Name: "randomness", Type: "bytes32"},
				{Name: "signature", Type: "bytes"},
			},
			// EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
			"EIP712Domain": []apitypes.Type{
				{Name: "name", Type: "string"},
				{Name: "version", Type: "string"},
				{Name: "chainId", Type: "uint256"},
				{Name: "verifyingContract", Type: "address"},
			}},
		PrimaryType: "SetRandomness",
		Domain: apitypes.TypedDataDomain{
			Name:              "DrandOracle",
			Version:           "1.0.0",
			ChainId:           math.NewHexOrDecimal256(s.chainID),
			VerifyingContract: s.drandOracleAddress.Hex(),
		},
		Message: apitypes.TypedDataMessage{
			"round":      math.NewHexOrDecimal256(int64(round)),
			"randomness": randomness,
			"signature":  signature,
		},
	}

	return s.SignEIP712TypedMessage(typeData)
}

func (s *Signer) SignEIP712TypedMessage(typedData *apitypes.TypedData) (signature []byte, err error) {
	var typedDataHash hexutil.Bytes
	typedDataHash, err = typedData.HashStruct(typedData.PrimaryType, typedData.Message)
	if err != nil {
		return
	}

	var domainSeparator hexutil.Bytes
	domainSeparator, err = typedData.HashStruct("EIP712Domain", typedData.Domain.Map())
	if err != nil {
		return
	}

	rawData := []byte(fmt.Sprintf("\x19\x01%s%s", string(domainSeparator), string(typedDataHash)))
	hash := crypto.Keccak256Hash(rawData)

	return s.Sign(hash.Bytes())
}

func (s *Signer) Sign(msg []byte) ([]byte, error) {
	signature, err := crypto.Sign(msg, s.privateKey)
	if err != nil {
		return nil, err
	}

	// Transform V from 0/1 to 27/28 according to the yellow paper
	// https://github.com/ethereum/go-ethereum/issues/19751#issuecomment-504900739
	if signature[crypto.RecoveryIDOffset] == 0 || signature[crypto.RecoveryIDOffset] == 1 {
		signature[crypto.RecoveryIDOffset] += 27
	}

	return signature, nil
}
