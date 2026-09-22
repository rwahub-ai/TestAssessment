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

    function testHealthFactorNoDebt() public {
        assertEq(engine.healthFactor(trader), type(uint256).max);
    }

    function testHealthFactorComputation() public {
        engine.updateEquity(trader, 150e18, 100e18);
        assertEq(engine.healthFactor(trader), 1.5e18);
    }

    function testIsLiquidatable() public {
        engine.updateEquity(trader, 90e18, 100e18);
        assertTrue(engine.isLiquidatable(trader));
    }

    function testToggleCrossMargin() public {
        vm.prank(trader);
        engine.toggleCrossMargin(true);
        assertTrue(engine.crossMarginEnabled(trader));
    }
}
