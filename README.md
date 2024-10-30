# Drand Oracle

A Solidity smart contract and updater service for bringing randomness from the [drand network](https://drand.love) on-chain.

## Overview

This project consists of two main components:

1. A Solidity smart contract (`DrandOracle.sol`) that stores randomness values along with necessary metadatas and signatures to verify the randomness off chain.
2. A Go updater service that fetches new randomness from drand and updates the contract.

## Contract

The randomness stored in the contract is verifiable off-chain but not on-chain. This is due to BLS signatures used by Drand network are not yet supported on EVM.
