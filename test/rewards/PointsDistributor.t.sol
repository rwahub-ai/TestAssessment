// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/rewards/PointsDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockVAR is ERC20 {
    constructor() ERC20("Variational", "VAR") {
        _mint(msg.sender, 10_000_000e18);
    }
}

contract PointsDistributorTest is Test {
    PointsDistributor public points;
    MockVAR public varToken;

    address owner = address(this);
    address keeper = address(0xBEE1);
    address trader = address(0xCAFE);

    function setUp() public {
        varToken = new MockVAR();
        points = new PointsDistributor(owner, address(varToken));
        points.setKeeper(keeper, true);

        varToken.approve(address(points), type(uint256).max);
        points.fundPool(1_000_000e18);
    }

    function test_KeeperCanCreditPoints() public {
        vm.prank(keeper);
        points.creditPoints(trader, 500, keccak256("daily-volume"));
        assertEq(points.pointsOf(trader), 500);
        assertEq(points.totalPointsIssued(), 500);
    }

    function test_NonKeeperCannotCreditPoints() public {
        vm.prank(trader);
        vm.expectRevert("Points: not a keeper");
        points.creditPoints(trader, 500, keccak256("daily-volume"));
    }

    function test_BatchCreditSumsCorrectly() public {
        address[] memory accounts = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        accounts[0] = trader;
        accounts[1] = keeper;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(keeper);
        points.creditPointsBatch(accounts, amounts, keccak256("referral"));

        assertEq(points.pointsOf(trader), 100);
        assertEq(points.pointsOf(keeper), 200);
        assertEq(points.totalPointsIssued(), 300);
    }

    function test_RedeemTransfersVarAtCurrentRate() public {
        vm.prank(keeper);
        points.creditPoints(trader, 1000, keccak256("volume"));

        // default rate: 100 bps = 1000 points -> 10 VAR
        vm.prank(trader);
        uint256 varAmount = points.redeem(1000);

        assertEq(varAmount, 10e18);
        assertEq(varToken.balanceOf(trader), 10e18);
        assertEq(points.pointsOf(trader), 0);
        assertEq(points.pointsRedeemed(trader), 1000);
    }

    function test_RedeemRevertsWithInsufficientPoints() public {
        vm.prank(trader);
        vm.expectRevert("Points: insufficient balance");
        points.redeem(1);
    }

    function test_OwnerCanUpdateRedemptionRate() public {
        points.setRedemptionRate(500); // 5%
        vm.prank(keeper);
        points.creditPoints(trader, 1000, keccak256("volume"));

        assertEq(points.previewRedeem(1000), 50e18);
    }

    function test_RedeemRevertsWhenPoolDepleted() public {
        // Drain the pool
        points.setRedemptionRate(10_000); // 100%: 1 point = 1 VAR
        vm.prank(keeper);
        points.creditPoints(trader, 2_000_000e18, keccak256("volume"));

        vm.prank(trader);
        vm.expectRevert("Points: pool depleted");
        points.redeem(2_000_000e18);
    }
}
