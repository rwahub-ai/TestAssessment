// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMarginEngine {
    function toggleCrossMargin(bool enabled) external;
    function updateEquity(address trader, uint256 equity, uint256 maintenanceMargin) external;
    function healthFactor(address trader) external view returns (uint256);
    function isLiquidatable(address trader) external view returns (bool);
    function isAtRisk(address trader) external view returns (bool);
}
