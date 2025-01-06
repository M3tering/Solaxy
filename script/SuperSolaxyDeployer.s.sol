// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import {SuperSolaxy} from "../src/Solaxy.sol";

contract SuperSolaxyDeployer is Script {
    bytes32 SALT = keccak256(abi.encodePacked("Tasty Superchain Solaxy"));
    string[] targetChains = [
        // "mainnet/op",
        // "mainnet/base",
        // "mainnet/celo",
        // "mainnet/mode",
        // "mainnet/unichain",
        // "mainnet/worldchain",
        // "mainnet/zora"
        "sepolia/op",
        "sepolia/base"
    ];

    function run() public {
        address preComputedAddress =
            vm.computeCreate2Address(SALT, keccak256(abi.encodePacked(type(SuperSolaxy).creationCode)));
        for (uint256 i = 0; i < targetChains.length; i++) {
            string memory target = targetChains[i];
            console.log(unicode"📡| Deploying to: ", preComputedAddress, "on ", target);
            vm.createSelectFork(vm.rpcUrl(target));
            deploySuperchainSolaxy(preComputedAddress);
        }
    }

    function deploySuperchainSolaxy(address _addr) public {
        if (_addr.code.length != 0) {
            //======================================================================//
            //  In forge scripts, using new MyContract{salt: salt}() will use the   //
            // deterministic deployer at 0x4e59b44847b379578588920ca78fbf26c0b4956c //
            //======================================================================//
            vm.startBroadcast(msg.sender);
            _addr = address(new SuperSolaxy{salt: SALT}());
            vm.stopBroadcast();
            console.log(unicode"✅| Successfully Deployed at ", _addr, "on chain id: ", block.chainid);
        }
        console.log(unicode"⏭️| Contract already exists at ", _addr, "on chain id: ", block.chainid);
    }
}
