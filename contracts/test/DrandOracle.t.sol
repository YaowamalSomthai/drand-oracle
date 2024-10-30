// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {stdJson} from "forge-std/StdJson.sol";
import {Test, console} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IDrandOracle} from "../src/IDrandOracle.sol";
import {DrandOracle} from "../src/DrandOracle.sol";

contract DrandOracleTest is Test {
    using stdJson for string;

    uint256 internal ownerPrivateKey;
    uint256 internal signerPrivateKey;
    address internal owner;
    address internal signer;

    string constant oracleName = "DrandOracle";
    string constant oracleVersion = "1.0.0";

    DrandOracle public oracle;

    bytes32 internal constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 _HASHED_NAME;
    bytes32 _HASHED_VERSION;

    function setUp() public {
        ownerPrivateKey = 0xA11CE;
        signerPrivateKey = 0xB0B;
        owner = vm.addr(ownerPrivateKey);
        signer = vm.addr(signerPrivateKey);

        oracle = new DrandOracle{salt: "DrandOracle"}(owner, signer);

        bytes32 hashedName = keccak256(bytes(oracleName));
        bytes32 hashedVersion = keccak256(bytes(oracleVersion));
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
    }

    function test_setRandomness_firstTime_success() public {
        uint64 round = 4493690;
        bytes32 randomnessBytes = bytes32(hex"a502d9e94fd02472fbd292e054893fb26a37490610a4e6ec29734a20f359b9c5");
        bytes memory signatureBytes =
            hex"b699e3214449474050112c80e01515b3250084e57f7fae9138e0a509aee2a641098450f9a5be3c6485c0fb8e8b3c8581029d1192ec6f9eb8d3a5e307f54ffd512a184562dc7f842d44b09e8481bc4ed38cfbd9c2d5b4e92f97e1baf6e97767c5";

        IDrandOracle.Random memory randomData =
            IDrandOracle.Random({round: round, randomness: randomnessBytes, signature: signatureBytes});

        bytes32 hash = _hashSetRandomness(randomData);
        bytes memory signature = _signMessage(hash, signerPrivateKey);

        oracle.setRandomness(randomData, signature);

        IDrandOracle.Random memory retrievedData = oracle.getRandomnessFromRound(round);
        assertEq(retrievedData.round, round);
        assertEq(retrievedData.randomness, randomnessBytes);
        assertEq(retrievedData.signature, signatureBytes);
        assertEq(oracle.earliestRound(), round);
        assertEq(oracle.latestRound(), round);
    }

    function _signMessage(bytes32 hash, uint256 privateKey) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }

    // --------------- hash functions ------------- //
    function _hashSetRandomness(IDrandOracle.Random memory _random) private view returns (bytes32) {
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

    // --------------- EIP712 signature tools ------------- //
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _buildDomainSeparator(), structHash));
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, _getChainId(), address(oracle)));
    }

    function _getChainId() private view returns (uint256 chainId) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
    }
}
