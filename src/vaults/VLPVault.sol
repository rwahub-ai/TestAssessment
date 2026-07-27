// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/vaults/IVLPVault.sol";

/**
 * @title VLPVault
 * @notice Variational Liquidity Pool vault. Depositors supply USDC that backs
 *         market-maker quoting capacity across the RFQ network and earn a
 *         pro-rata share of protocol fees + funding spread, represented as
 *         an ERC-4626-style share token without pulling in the full 4626
 *         interface (kept intentionally minimal for the PoC).
 */
contract VLPVault is IVLPVault, ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20  public immutable asset;
    uint256 public totalAssets_;
    uint256 public withdrawalCooldown = 7 days;
    mapping(address => uint256) public lastDepositAt;

    constructor(address _asset) ERC20("Variational LP Share", "vLP") Ownable(msg.sender) {
        asset = IERC20(_asset);
    }

    function sharePrice() public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 1e18;
        return (totalAssets_ * 1e18) / supply;
    }

    function totalAssets() external view returns (uint256) {
        return totalAssets_;
    }

    function deposit(uint256 assets) external nonReentrant returns (uint256 shares) {
        require(assets > 0, "zero deposit");
        uint256 price = sharePrice();
        shares = (assets * 1e18) / price;

        asset.safeTransferFrom(msg.sender, address(this), assets);
        totalAssets_ += assets;
        lastDepositAt[msg.sender] = block.timestamp;
        _mint(msg.sender, shares);

        emit Deposited(msg.sender, assets, shares);
    }

    function withdraw(uint256 shares) external nonReentrant returns (uint256 assets) {
        require(shares > 0, "zero withdraw");
        require(block.timestamp >= lastDepositAt[msg.sender] + withdrawalCooldown, "cooldown active");

        uint256 price = sharePrice();
        assets = (shares * price) / 1e18;

        _burn(msg.sender, shares);
        totalAssets_ -= assets;
        asset.safeTransfer(msg.sender, assets);

        emit Withdrawn(msg.sender, assets, shares);
    }

    function accrueYield(uint256 amount) external onlyOwner {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        totalAssets_ += amount;
        emit YieldAccrued(amount);
    }

    function setWithdrawalCooldown(uint256 cooldown) external onlyOwner {
        require(cooldown <= 30 days, "too long");
        withdrawalCooldown = cooldown;
    }
}
