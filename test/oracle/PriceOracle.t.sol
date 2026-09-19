// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/PriceOracle.sol";

contract PriceOracleTest is Test {
    PriceOracle public oracle;

    address owner = address(this);
    address reporterA = address(0xA1);
    address reporterB = address(0xA2);
    address reporterC = address(0xA3);

    bytes32 constant BTC_PERP = keccak256("BTC-PERP");


    function test_NonReporterCannotReport() public {
        vm.prank(address(0xBAD));
        vm.expectRevert("Oracle: not a reporter");
        oracle.reportPrice(BTC_PERP, 100e18);
    }

    function test_StalenessDetection() public {
        vm.prank(reporterA);
        oracle.reportPrice(BTC_PERP, 107_000e18);
        oracle.finalize(BTC_PERP);

        assertFalse(oracle.isStale(BTC_PERP));

        vm.warp(block.timestamp + oracle.stalenessThreshold() + 1);
        assertTrue(oracle.isStale(BTC_PERP));
    }

    function test_TwapAveragesRecentCheckpoints() public {
        vm.prank(reporterA);
        oracle.reportPrice(BTC_PERP, 100e18);
        oracle.finalize(BTC_PERP);

        vm.warp(block.timestamp + 30);
        vm.prank(reporterA);
        oracle.reportPrice(BTC_PERP, 200e18);
        oracle.finalize(BTC_PERP);

        uint256 t = oracle.twap(BTC_PERP, 3600);
        assertEq(t, 150e18);
    }

    function test_RoundClearsAfterFinalize() public {
        vm.prank(reporterA);
        oracle.reportPrice(BTC_PERP, 100e18);
        oracle.finalize(BTC_PERP);

        vm.expectRevert("Oracle: no reports");
        oracle.finalize(BTC_PERP);
    }
}
