// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @title IDrandOracle
/// @notice Interface for the DrandOracle contract
interface IDrandOracle {
    /// @notice Structure containing randomness data and associated signatures
    /// @param round The drand round number
    /// @param randomness The drand round randomness value
    /// @param signature The drand round signature
    struct Random {
        uint64 round;
        uint64 timestamp;
        bytes32 randomness;
        bytes signature;
    }

    /// @notice Thrown when an address parameter is zero
    error InvalidAddress();
    /// @notice Thrown when a signature verification fails
    error InvalidSignature();
    /// @notice Thrown when accessing or setting an invalid round
    error InvalidRound();
    /// @notice Thrown when accessing or setting an invalid round timestamp
    error InvalidRoundTimestamp();
    /// @notice Thrown when input parameters are invalid or empty
    error InvalidInput();

    /// @notice Emitted when the signer address is updated
    /// @param signer The new signer address
    event SignerUpdated(address signer);

    /// @notice Emitted when new randomness is recorded
    /// @param round The drand round number
    /// @param randomness The drand round randomness value
    /// @param signature The drand round signature
    event RandomnessUpdated(uint64 round, bytes32 randomness, bytes signature);

    /// @notice Sets new randomness data for the new round
    /// @param _random The drand round randomness result
    /// @param _signature The signature authorizing this update
    function setRandomness(Random calldata _random, bytes calldata _signature) external;

    /// @notice Retrieves the complete randomness data for a specific round
    /// @param _round The round number to query
    /// @return The Random struct containing the round's data
    function getRandomnessFromRound(uint64 _round) external view returns (Random memory);

    /// @notice Retrieves the complete randomness data for a specific timestamp
    /// @param _timestamp The timestamp to query
    /// @return The Random struct containing the timestamp's data
    function getRandomnessFromTimestamp(uint64 _timestamp) external view returns (Random memory);

    /// @notice Returns the latest round number that has been recorded
    /// @return The current latest round number
    function latestRound() external view returns (uint64);

    /// @notice Returns the earliest round number that has been recorded
    /// @return The earliest round number
    function earliestRound() external view returns (uint64);

    /// @notice Updates the signer address
    /// @param _signer The new signer address
    /// @param _signature Signature from the current signer authorizing this change
    function setSigner(address _signer, bytes calldata _signature) external;

    /// @notice Pauses the contract
    function pause() external;

    /// @notice Unpauses the contract
    function unpause() external;

    /// @notice Returns the address authorized to sign randomness updates
    function signer() external view returns (address);
}
