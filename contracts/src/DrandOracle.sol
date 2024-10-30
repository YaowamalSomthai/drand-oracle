// SPDX-License-Identifier: Apache-2.0

/*
 Copyright 2024 Galxe.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
pragma solidity ^0.8.24;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IDrandOracle} from "./IDrandOracle.sol";

/// @title DrandOracle
/// @notice A contract that stores and verifies randomness from the Drand network
/// @dev Implements EIP-712 for secure message signing and verification
/// @custom:security-contact security@example.com
contract DrandOracle is IDrandOracle, Ownable2Step, Pausable, EIP712 {
    /// @notice Thrown when an address parameter is zero
    error InvalidAddress();
    /// @notice Thrown when a signature verification fails
    error InvalidSignature();
    /// @notice Thrown when accessing or setting an invalid round
    error InvalidRound();
    /// @notice Thrown when input parameters are invalid or empty
    error InvalidInput();

    /// @notice Mapping of round numbers to their corresponding randomness data
    mapping(uint64 => Random) public values;

    /// @notice The earliest round number that has been recorded
    uint64 private _earliestRound = type(uint64).max;

    /// @notice The most recent round number that has been recorded
    uint64 private _latestRound = 0;

    /// @notice The address authorized to sign randomness updates
    address private _signer;

    /// @notice Initializes the contract with an owner and signer
    /// @param _initialOwner The address that will own the contract
    /// @param _initialSigner The address authorized to sign randomness updates
    /// @dev Both addresses must be non-zero
    constructor(address _initialOwner, address _initialSigner) Ownable(_initialOwner) EIP712("DrandOracle", "1.0.0") {
        if (_initialSigner == address(0)) {
            revert InvalidAddress();
        }
        if (_initialOwner == address(0)) {
            revert InvalidAddress();
        }
        _signer = _initialSigner;
        emit SignerUpdated(_signer);
    }

    /// @notice Sets new randomness data for the new round, sequentially
    /// @param _random The drand round randomness result
    /// @param _signature The signature authorizing this update
    /// @dev Round must be greater than the latest recorded round
    function setRandomness(Random calldata _random, bytes calldata _signature) external whenNotPaused {
        if (_random.randomness.length == 0 || _random.signature.length == 0) {
            // revert InvalidInput();
            revert("InvalidInput");
        }
        if (_random.round == 0) {
            // revert InvalidRound();
            revert("InvalidRound");
        }
        if (!_verify(_hashSetRandomness(_random), _signature)) {
            // revert InvalidSignature();
            revert("InvalidSignature");
        }
        if (_latestRound >= _random.round) {
            // revert InvalidRound();
            revert("InvalidRound");
        }
        if (_latestRound > 0 && _random.round != _latestRound + 1) {
            // revert InvalidRound();
            revert("InvalidRound");
        }
        if (_earliestRound == type(uint64).max) {
            _earliestRound = _random.round;
        }
        _latestRound = _random.round;
        values[_random.round] = _random;
        emit RandomnessUpdated(_random.round, _random.randomness, _random.signature);
    }

    /// @notice Retrieves the complete randomness data for a specific round
    /// @param _round The round number to query
    /// @return The Random struct containing the round's data
    /// @dev Reverts if the round is greater than the latest round
    function getRandomnessFromRound(uint64 _round) external view returns (Random memory) {
        if (_round > _latestRound || _round < _earliestRound) {
            revert InvalidRound();
        }
        return values[_round];
    }

    /// @notice Retrieves just the randomness value for a specific round
    /// @param _round The round number to query
    /// @return The randomness value for the round
    /// @dev Reverts if the round is greater than the latest round
    function getRandomnessValueFromRound(uint64 _round) external view returns (bytes32) {
        if (_round > _latestRound || _round < _earliestRound) {
            revert InvalidRound();
        }
        return values[_round].randomness;
    }

    /// @notice Returns the latest round number that has been recorded
    /// @return The current latest round number
    function latestRound() external view returns (uint64) {
        return _latestRound;
    }

    /// @notice Returns the earliest round number that has been recorded
    /// @return The earliest round number
    function earliestRound() external view returns (uint64) {
        return _earliestRound;
    }

    /// @notice Updates the signer address
    /// @param _newSigner The new signer address
    /// @param _signature Signature from the current signer authorizing this change
    /// @dev The new signer address must be non-zero
    function setSigner(address _newSigner, bytes calldata _signature) external whenNotPaused {
        if (_newSigner == address(0)) {
            revert InvalidAddress();
        }
        if (!_verify(_hashSetSigner(_newSigner), _signature)) {
            revert InvalidSignature();
        }
        _signer = _newSigner;
        emit SignerUpdated(_signer);
    }

    /// @notice Pauses the contract
    /// @dev Can only be called by the contract owner
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    /// @dev Can only be called by the contract owner
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Verifies a signature against a hash
    /// @param _hash The hash to verify
    /// @param _signature The signature to verify
    /// @return bool True if the signature is valid, false otherwise
    function _verify(bytes32 _hash, bytes calldata _signature) private view returns (bool) {
        return ECDSA.recover(_hash, _signature) == _signer;
    }

    /// @notice Creates a typed data hash for randomness updates
    /// @param _random The drand round randomness result being set
    /// @return bytes32 The EIP-712 compliant hash
    function _hashSetRandomness(Random calldata _random) private view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("SetRandomness(uint64 round,bytes32 randomness,bytes signature)"),
                    _random.round,
                    _random.randomness,
                    keccak256(_random.signature)
                )
            )
        );
    }

    /// @notice Creates a typed data hash for signer updates
    /// @param _newSigner The new signer address
    /// @return bytes32 The EIP-712 compliant hash
    function _hashSetSigner(address _newSigner) private view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(keccak256("SetSigner(address signer)"), _newSigner)));
    }

    /// @notice Returns the signer address
    /// @return The signer address
    function signer() external view returns (address) {
        return _signer;
    }
}
