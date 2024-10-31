# 🎲 Drand Oracle Updater

A simple updater service that fetches new randomness from [drand](https://drand.love) and updates the Drand Oracle contract.

## 📖 Overview

The updater service is a simple Golang application that:

1. Connects to a Ethereum network via an RPC client.
2. Subscribes to a Drand randomness feed.
3. Sets up a listener for new randomness rounds.
4. Sets up a catch-up mechanism to update the Drand Oracle contract with historical randomness based on the latest round information from the Drand Oracle contract.
5. Sends a transaction to the Drand Oracle contract to update the randomness.

Note that if the Drand Oracle contract is not yet tracking rounds, the updater will start submitting randomness updates from the genesis round defined in the configuration by `GENESIS_ROUND` environment variable.

## 🐳 Docker

Pull the Docker image from the [GitHub Container Registry](https://github.com/orgs/Galxe/packages?repo_name=drand-oracle) or build it locally using the `Dockerfile`.

## 🚀 Environment Variables

The updater requires the following environment variables:

- `DRAND_URLS`: A list of Drand URLs.
- `CHAIN_HASH`: The Drand chain hash.
- `DRAND_ORACLE_ADDRESS`: The address of the Drand Oracle contract.
- `RPC`: The RPC URL.
- `CHAIN_ID`: The chain ID.
- `SIGNER_PRIVATE_KEY`: The private key of the signer.
- `SENDER_PRIVATE_KEY`: The private key of the sender.
- `GENESIS_ROUND`: The genesis round.

## 🕺 Running Locally

Let's start by setting up the local development environment. For this, we'll:

1. Use [Anvil](https://book.getfoundry.sh/anvil/) to run a local Ethereum chain.
2. Deploy the Drand Oracle contract to the local chain.
3. Run the updater service against the local chain.
4. Watch the updater service submit randomness updates to the Drand Oracle contract.

Note that signer and sender private keys are provided by Anvil and hard-coded in the `Makefile`. Do not use these keys in production.

### Prerequisites

- [Golang](https://go.dev/dl/)
- [Foundry](https://book.getfoundry.sh/getting-started/)

### Start Local Anvil Chain

```bash
anvil
```

### Deploy Drand Oracle Contract

Go to the `contracts` directory and run:

```bash
make deploy-anvil
```

### Run Updater Service

Go to the `updater` directory and run:

```bash
make local-run-anvil
```
