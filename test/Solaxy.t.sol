// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, console2} from "forge-std/Test.sol";
import {Solaxy} from "../src/Solaxy.sol";

contract SolaxyTest is Test {
    Solaxy public solaxy;

    function setUp() public {
        solaxy = new Solaxy(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    }
}
