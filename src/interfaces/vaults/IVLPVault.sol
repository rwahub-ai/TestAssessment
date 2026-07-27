// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVLPVault {
    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(address indexed user, uint256 assets, uint256 shares);
    event YieldAccrued(uint256 amount);

    function deposit(uint256 assets) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 assets);
    function sharePrice() external view returns (uint256);
    function totalAssets() external view returns (uint256);
}
