// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {DrandOracle} from "../../src/DrandOracle.sol";

contract DrandOracleScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER");
        address signer = vm.envAddress("SIGNER");
        vm.startBroadcast(deployerPrivateKey);

        DrandOracle oracle = new DrandOracle{salt: "DrandOracle"}(owner, signer);
        console.log("DrandOracle deployed at:", address(oracle));

        vm.stopBroadcast();
    }
}
