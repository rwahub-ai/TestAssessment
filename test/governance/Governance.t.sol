// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/token/VARToken.sol";
import "../../src/staking/VARStaking.sol";
import "../../src/governance/VariationalTimelock.sol";
import "../../src/governance/VariationalGovernor.sol";
import "../../src/vesting/VestingVault.sol";
import "../../src/interfaces/token/IVARStaking.sol";
import "../../src/interfaces/governance/IVariationalGovernor.sol";

contract VARStakingTest is Test {
    VARToken public var_;
    VARStaking public staking;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    function setUp() public {
        var_ = new VARToken(owner);
        staking = new VARStaking(address(var_), owner);

        var_.addMinter(owner);
        var_.mint(alice, 1_000_000e18);
        var_.mint(bob, 1_000_000e18);
        var_.mint(owner, 10_000_000e18);

        vm.prank(alice);
        var_.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        var_.approve(address(staking), type(uint256).max);

        var_.approve(address(staking), type(uint256).max);
        staking.fundRewards(1_000_000e18, 30 days);
    }

    function testStakeBoostsVotingPowerByTier() public {
        vm.prank(alice);
        staking.stake(100e18, IVARStaking.LockTier.GOLD); // 2.50x

        vm.prank(bob);
        staking.stake(100e18, IVARStaking.LockTier.FLEXIBLE); // 1.00x

        assertEq(staking.votingPower(alice), 250e18);
        assertEq(staking.votingPower(bob), 100e18);
    }

    

    function testRewardsAccrueOverTime() public {
        vm.prank(alice);
        staking.stake(1000e18, IVARStaking.LockTier.FLEXIBLE);

        vm.warp(block.timestamp + 1 days);

        uint256 pending = staking.pendingRewards(alice);
        assertGt(pending, 0);
    }
}

contract VariationalGovernorTest is Test {
    VARToken public var_;
    VARStaking public staking;
    VariationalTimelock public timelock;
    VariationalGovernor public governor;

    address owner = address(this);
    address alice = address(0xA11CE);

    function setUp() public {
        var_ = new VARToken(owner);
        staking = new VARStaking(address(var_), owner);
        timelock = new VariationalTimelock(owner, 2 days);
        governor = new VariationalGovernor(address(staking), address(timelock));

        var_.addMinter(owner);
        var_.mint(alice, 5_000_000e18);

        vm.prank(alice);
        var_.approve(address(staking), type(uint256).max);
        vm.prank(alice);
        staking.stake(5_000_000e18, IVARStaking.LockTier.GOLD); // 12.5M voting power
    }

    

    function testCannotVoteTwice() public {
        vm.prank(alice);
        uint256 id = governor.propose("Test", "desc", address(0), "");
        vm.warp(block.timestamp + governor.votingDelay() + 1);

        uint8 support = governor.SUPPORT_FOR();

        vm.prank(alice);
        governor.castVote(id, support);

        vm.prank(alice);
        vm.expectRevert("Governor: already voted");
        governor.castVote(id, support);
    }
}

contract VestingVaultTest is Test {
    VARToken public var_;
    VestingVault public vault;

    

    function testFullyVestedAfterDuration() public {
        uint256 id = vault.createSchedule(beneficiary, 1_000_000e18, block.timestamp, 0, 365 days, true);
        assertEq(vault.releasableAmount(id), 1_000_000e18);
    }

    function testRevokeReturnsUnvestedOnly() public {
        uint256 id = vault.createSchedule(beneficiary, 1_000_000e18, block.timestamp, 0, 365 days, true);
        vm.warp(block.timestamp + 182.5 days);

        uint256 ownerBalBefore = var_.balanceOf(owner);
        vault.revoke(id);
        uint256 returned = var_.balanceOf(owner) - ownerBalBefore;

        assertApproxEqRel(returned, 500_000e18, 0.01e18);
    }
}
