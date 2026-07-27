// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/vaults/VLPVault.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") { _mint(msg.sender, 1_000_000e6); }
}

contract VLPVaultTest is Test {
    VLPVault vault;
    MockUSDC usdc;
    address lp = address(0xD00D);

    function setUp() public {
        usdc = new MockUSDC();
        vault = new VLPVault(address(usdc));
        usdc.transfer(lp, 10_000e6);
    }

    function testDeposit() public {
        vm.startPrank(lp);
        usdc.approve(address(vault), 1_000e6);
        uint256 shares = vault.deposit(1_000e6);
        vm.stopPrank();
        assertEq(shares, 1_000e18 / 1); // 1:1 at first deposit given 1e18 initial price
        assertEq(vault.totalAssets(), 1_000e6);
    }

    function testWithdrawBlockedByCooldown() public {
        vm.startPrank(lp);
        usdc.approve(address(vault), 1_000e6);
        uint256 shares = vault.deposit(1_000e6);
        vm.expectRevert("cooldown active");
        vault.withdraw(shares);
        vm.stopPrank();
    }

    function testWithdrawAfterCooldown() public {
        vm.startPrank(lp);
        usdc.approve(address(vault), 1_000e6);
        uint256 shares = vault.deposit(1_000e6);
        vm.warp(block.timestamp + 8 days);
        vault.withdraw(shares);
        vm.stopPrank();
        assertEq(vault.totalAssets(), 0);
    }
}
