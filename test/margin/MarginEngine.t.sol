// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/margin/MarginEngine.sol";

contract MarginEngineTest is Test {
    MarginEngine engine;
    address trader = address(0xBEEF);

    function setUp() public {
        engine = new MarginEngine(address(0x1));
    }

}
