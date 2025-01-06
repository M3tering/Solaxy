// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import {SuperSolaxy} from "../src/Solaxy.sol";

contract preComputeAddress is Script {
    bytes32 SALT = keccak256(abi.encodePacked("Superchain"));

    function run() public view {
        console.log(unicode"⏳| Computing address with salt: ", vm.toString(SALT));

        bytes32 codeHash = keccak256(abi.encodePacked(type(SuperSolaxy).creationCode));
        console.log(unicode"⏳| Code hash is: ", vm.toString(codeHash));

        address preComputedAddress = vm.computeCreate2Address(SALT, codeHash);
        console.log(unicode"✨| Derived address: ", preComputedAddress);
    }
}
