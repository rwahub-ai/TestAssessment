// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVARStaking {
    enum LockTier {
        FLEXIBLE,   // 0 days   — 1.00x boost, withdraw anytime
        BRONZE,     // 30 days  — 1.25x boost
        SILVER,     // 90 days  — 1.75x boost
        GOLD        // 180 days — 2.50x boost
    }

    struct Stake {
        uint256 amount;
        uint256 boostedAmount;
        LockTier tier;
        uint256 startTime;
        uint256 unlockTime;
        uint256 rewardDebt;
        bool withdrawn;
    }

    event Staked(address indexed user, uint256 indexed stakeId, uint256 amount, LockTier tier, uint256 unlockTime);
    event Unstaked(address indexed user, uint256 indexed stakeId, uint256 amount, uint256 penalty);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRatePerSecond);
    event RewardsFunded(uint256 amount, uint256 newFinishTime);

    function stake(uint256 amount, LockTier tier) external returns (uint256 stakeId);
    function unstake(uint256 stakeId) external;
    function emergencyUnstake(uint256 stakeId) external;
    function claimRewards() external returns (uint256 claimed);

    function pendingRewards(address user) external view returns (uint256);
    function votingPower(address user) external view returns (uint256);
    function totalBoostedStaked() external view returns (uint256);
    function getUserStakes(address user) external view returns (uint256[] memory);
    function getStake(address user, uint256 stakeId) external view returns (Stake memory);
}
