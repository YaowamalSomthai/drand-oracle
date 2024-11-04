// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BaseScript} from "../utils/Base.s.sol";
import {DrandOracle} from "../../src/DrandOracle.sol";

contract DrandOracleScript is BaseScript {
    function run() external chain broadcaster {
        // bytes32 CREATE2_SALT = vm.envBytes32("CREATE2_SALT");
        address owner = vm.envAddress("OWNER");
        address signer = vm.envAddress("SIGNER");
        bytes32 chainHash = vm.envBytes32("CHAIN_HASH");

        console.log("Owner:", owner);
        console.log("Signer:", signer);
        console.log("Chain hash:");
        console.logBytes32(chainHash);

        DrandOracle oracle = new DrandOracle(owner, signer, chainHash);
        console.log("DrandOracle deployed at:", address(oracle));
    }
}
