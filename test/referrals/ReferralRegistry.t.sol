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

}
