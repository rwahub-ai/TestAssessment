// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/InsuranceFund.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 10_000_000e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract InsuranceFundTest is Test {
    InsuranceFund public fund;
    MockUSDC public usdc;

    address owner = address(this);
    address variationalPro = address(0x0aC1);
    address lp1 = address(0xBEEF);
    address lp2 = address(0xCAFE);

    function setUp() public {
        usdc = new MockUSDC();
        fund = new InsuranceFund(owner, address(usdc));
        fund.setVariationalPro(variationalPro);

        usdc.transfer(lp1, 100_000e6);
        usdc.transfer(lp2, 100_000e6);
        usdc.transfer(variationalPro, 50_000e6);

        vm.prank(lp1);
        usdc.approve(address(fund), type(uint256).max);
        vm.prank(lp2);
        usdc.approve(address(fund), type(uint256).max);
        vm.prank(variationalPro);
        usdc.approve(address(fund), type(uint256).max);
    }

    function test_FirstDepositMintsSharesOneToOne() public {
        vm.prank(lp1);
        uint256 shares = fund.deposit(10_000e6);
        assertEq(shares, 10_000e6);
        assertEq(fund.totalAssets(), 10_000e6);
    }

    function test_SecondDepositMintsProRataShares() public {
        vm.prank(lp1);
        fund.deposit(10_000e6);

        vm.prank(variationalPro);
        fund.receiveFee(1_000e6, keccak256("BTC-PERP")); // fund grows to 11,000

        vm.prank(lp2);
        uint256 shares = fund.deposit(11_000e6);
        // lp2 deposits equal to current totalAssets, so should mint totalShares worth
        assertEq(shares, fund.totalShares() - 10_000e6);
    }

    function test_WithdrawalRequiresCooldown() public {
        vm.startPrank(lp1);
        uint256 shares = fund.deposit(10_000e6);
        fund.requestWithdrawal(shares);
        vm.expectRevert("InsuranceFund: cooldown active");
        fund.withdraw();
        vm.stopPrank();
    }

    function test_WithdrawalAfterCooldown() public {
        vm.startPrank(lp1);
        uint256 shares = fund.deposit(10_000e6);
        fund.requestWithdrawal(shares);
        vm.stopPrank();

        vm.warp(block.timestamp + fund.WITHDRAWAL_COOLDOWN() + 1);

        vm.prank(lp1);
        uint256 amount = fund.withdraw();
        assertEq(amount, 10_000e6);
        assertEq(usdc.balanceOf(lp1), 100_000e6);
    }

    function test_OnlyVariationalProCanSocializeLoss() public {
        vm.prank(lp1);
        fund.deposit(10_000e6);

        vm.expectRevert("InsuranceFund: not VariationalPro");
        fund.socializeLoss(1_000e6, keccak256("BTC-PERP"), 1);

        vm.prank(variationalPro);
        fund.socializeLoss(1_000e6, keccak256("BTC-PERP"), 1);
        assertEq(fund.totalAssets(), 9_000e6);
    }

    function test_SocializeLossCannotExceedFund() public {
        vm.prank(lp1);
        fund.deposit(1_000e6);

        vm.prank(variationalPro);
        vm.expectRevert("InsuranceFund: exceeds fund");
        fund.socializeLoss(5_000e6, keccak256("BTC-PERP"), 1);
    }

    function test_IsHealthyReflectsBalance() public {
        assertFalse(fund.isHealthy());
        vm.prank(lp1);
        fund.deposit(1e6);
        assertTrue(fund.isHealthy());
    }
}
