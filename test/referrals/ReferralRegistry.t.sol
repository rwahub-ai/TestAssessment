// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/referrals/ReferralRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 10_000_000e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract ReferralRegistryTest is Test {
    ReferralRegistry public registry;
    MockUSDC public usdc;

    address owner = address(this);
    address variationalPro = address(0x0aC1);
    address referrer = address(0xBEEF);
    address referee = address(0xCAFE);

    function setUp() public {
        usdc = new MockUSDC();
        registry = new ReferralRegistry(owner, address(usdc));
        registry.setVariationalPro(variationalPro);

        usdc.transfer(address(registry), 1_000_000e6); // fund reward pool
    }

    function test_RegisterAndLinkCode() public {
        vm.prank(referrer);
        registry.registerCode("VARIATIONAL1");

        vm.prank(referee);
        registry.linkReferee(referee, "VARIATIONAL1");

        assertEq(registry.referrerOf(referee), referrer);
    }

    function test_CannotRegisterDuplicateCode() public {
        vm.prank(referrer);
        registry.registerCode("VARIATIONAL1");

        vm.prank(referee);
        vm.expectRevert("Referral: code taken");
        registry.registerCode("VARIATIONAL1");
    }

    function test_CannotSelfRefer() public {
        vm.startPrank(referrer);
        registry.registerCode("SELFCODE");
        vm.expectRevert("Referral: self-referral");
        registry.linkReferee(referrer, "SELFCODE");
        vm.stopPrank();
    }

    function test_AccrueVolumeCreditsStarterTier() public {
        vm.prank(referrer);
        registry.registerCode("STARTER1");
        vm.prank(referee);
        registry.linkReferee(referee, "STARTER1");

        vm.prank(variationalPro);
        registry.accrueVolume(referee, 10_000e6, 100e6); // 100 USDC revenue

        // Starter tier = 10% share
        assertEq(registry.pendingRewards(referrer), 10e6);
        assertEq(registry.referredVolume(referrer), 10_000e6);
    }

    function test_TierUpgradesShareAsVolumeGrows() public {
        vm.prank(referrer);
        registry.registerCode("GROWTH1");
        vm.prank(referee);
        registry.linkReferee(referee, "GROWTH1");

        vm.prank(variationalPro);
        registry.accrueVolume(referee, 600_000e6, 1_000e6); // pushes past 500k -> Growth tier (15%)

        assertEq(registry.pendingRewards(referrer), 150e6);
    }

    function test_ClaimRewardsTransfersTokens() public {
        vm.prank(referrer);
        registry.registerCode("CLAIM1");
        vm.prank(referee);
        registry.linkReferee(referee, "CLAIM1");

        vm.prank(variationalPro);
        registry.accrueVolume(referee, 10_000e6, 100e6);

        vm.prank(referrer);
        uint256 amount = registry.claimRewards();

        assertEq(amount, 10e6);
        assertEq(usdc.balanceOf(referrer), 10e6);
        assertEq(registry.pendingRewards(referrer), 0);
    }

    function test_UnlinkedRefereeAccruesNothing() public {
        vm.prank(variationalPro);
        registry.accrueVolume(referee, 10_000e6, 100e6);
        assertEq(registry.pendingRewards(referrer), 0);
    }
}
