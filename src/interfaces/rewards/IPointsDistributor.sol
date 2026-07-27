// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPointsDistributor
 * @notice Tracks off-chain-computed "points" (trading volume, referrals,
 *         governance participation) that back the Leaderboard and are
 *         redeemable for $VAR at a rate the owner can adjust. Points are
 *         credited by a trusted keeper rather than derived on-chain, since
 *         the scoring formula (volume tiers, streak bonuses, etc.) is
 *         expected to evolve without requiring a contract upgrade.
 */
interface IPointsDistributor {
    event PointsCredited(address indexed account, uint256 amount, bytes32 indexed reason);
    event PointsRedeemed(address indexed account, uint256 points, uint256 varAmount);
    event RedemptionRateUpdated(uint256 newRateBps);
    event KeeperUpdated(address indexed keeper, bool active);

    function creditPoints(address account, uint256 amount, bytes32 reason) external;
    function creditPointsBatch(address[] calldata accounts, uint256[] calldata amounts, bytes32 reason) external;
    function redeem(uint256 points) external returns (uint256 varAmount);

    function pointsOf(address account) external view returns (uint256);
    function totalPointsIssued() external view returns (uint256);
    function previewRedeem(uint256 points) external view returns (uint256 varAmount);
}
