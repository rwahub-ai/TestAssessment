// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILiquidationEngine {
    event PositionLiquidated(uint256 indexed positionId, address indexed trader, address indexed liquidator, uint256 penalty);

    function liquidate(uint256 positionId) external;
    function liquidationPenaltyBps() external view returns (uint256);
}
