// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IReferralRegistry {
    struct Tier {
        uint256 minVolume;   // cumulative referred volume (USDC, 6 decimals) to qualify
        uint256 shareBps;    // referrer's share of spread revenue, in bps
    }

    event ReferrerRegistered(address indexed referrer, bytes32 code);
    event RefereeLinked(address indexed referee, address indexed referrer, bytes32 code);
    event VolumeAccrued(address indexed referrer, address indexed referee, uint256 volume);
    event RewardPaid(address indexed referrer, uint256 amount);
    event TierUpdated(uint256 index, uint256 minVolume, uint256 shareBps);

    function registerCode(bytes32 code) external;
    function linkReferee(address referee, bytes32 code) external;
    function accrueVolume(address referee, uint256 volumeUsdc, uint256 revenueUsdc) external;
    function claimRewards() external returns (uint256 amount);

    function referrerOf(address referee) external view returns (address);
    function codeOwner(bytes32 code) external view returns (address);
    function referredVolume(address referrer) external view returns (uint256);
    function pendingRewards(address referrer) external view returns (uint256);
    function currentTier(address referrer) external view returns (Tier memory);
}
