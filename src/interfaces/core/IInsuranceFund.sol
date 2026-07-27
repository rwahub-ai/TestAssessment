// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IInsuranceFund
 * @notice Backstops socialized losses that liquidation could not fully cover
 *         (bankrupt positions where the loss exceeds posted margin). Funded
 *         by depositors who earn a share of protocol liquidation fees and,
 *         in return, absorb losses pro-rata to their share of the fund if it
 *         is ever drawn down below its target ratio.
 */
interface IInsuranceFund {
    struct Depositor {
        uint256 shares;
        uint256 depositedAt;
    }

    event Deposited(address indexed depositor, uint256 amount, uint256 shares);
    event WithdrawRequested(address indexed depositor, uint256 shares, uint256 unlockAt);
    event Withdrawn(address indexed depositor, uint256 amount, uint256 shares);
    event LossSocialized(uint256 amount, bytes32 indexed marketId, uint256 positionId);
    event FeeReceived(uint256 amount, bytes32 indexed marketId);

    function deposit(uint256 amount) external returns (uint256 shares);
    function requestWithdrawal(uint256 shares) external;
    function withdraw() external returns (uint256 amount);

    function socializeLoss(uint256 amount, bytes32 marketId, uint256 positionId) external;
    function receiveFee(uint256 amount, bytes32 marketId) external;

    function totalAssets() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function sharePrice() external view returns (uint256);
    function balanceOf(address depositor) external view returns (uint256 shares, uint256 assets);
    function isHealthy() external view returns (bool);
}
