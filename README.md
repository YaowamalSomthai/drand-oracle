# 🎲 Drand Oracle

A Solidity smart contract and updater service for bringing randomness from the [drand network](https://drand.love) on-chain.

## 📄 Contract

The `DrandOracle` smart contract serves as an on-chain source of randomness by storing values from the drand network.

For more information, see the [contract README](contracts/README.md).

## 🔄 Updater

The updater service fetches new randomness from drand and updates the `DrandOracle` contract with its managed signer and sender EOA addresses.

For more information, see the [updater README](updater/README.md).

## 📝 License

This project is licensed under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to open an issue or submit a Pull Request.
