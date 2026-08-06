// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/margin/IMarginEngine.sol";
import "../interfaces/core/IVariationalPro.sol";

/**
 * @title MarginEngine
 * @notice Cross-margin risk engine. Aggregates a trader's open positions across
 *         all settlement pools into a single account-level health factor, so
 *         collateral posted for one position can offset losses on another
 *         instead of every position being margined in isolation.
 */
contract MarginEngine is IMarginEngine, Ownable, ReentrancyGuard {
    IVariationalPro public variationalPro;

    mapping(address => uint256) public accountEquity;
    mapping(address => uint256) public accountMaintenanceMargin;
    mapping(address => bool)    public crossMarginEnabled;

    uint256 public constant HEALTH_FACTOR_LIQUIDATION = 1e18; // 1.0
    uint256 public constant HEALTH_FACTOR_WARNING      = 1.1e18;

    event CrossMarginToggled(address indexed trader, bool enabled);
    event EquityUpdated(address indexed trader, uint256 equity, uint256 maintenanceMargin);

    constructor(address _variationalPro) Ownable(msg.sender) {
        variationalPro = IVariationalPro(_variationalPro);
    }

    function setVariationalPro(address _variationalPro) external onlyOwner {
        variationalPro = IVariationalPro(_variationalPro);
    }

    function toggleCrossMargin(bool enabled) external {
        crossMarginEnabled[msg.sender] = enabled;
        emit CrossMarginToggled(msg.sender, enabled);
    }

    function updateEquity(address trader, uint256 equity, uint256 maintenanceMargin) external onlyOwner {
        accountEquity[trader] = equity;
        accountMaintenanceMargin[trader] = maintenanceMargin;
        emit EquityUpdated(trader, equity, maintenanceMargin);
    }

    function healthFactor(address trader) public view returns (uint256) {
        uint256 mm = accountMaintenanceMargin[trader];
        if (mm == 0) return type(uint256).max;
        return (accountEquity[trader] * 1e18) / mm;
    }

    function isLiquidatable(address trader) external view returns (bool) {
        return healthFactor(trader) < HEALTH_FACTOR_LIQUIDATION;
    }

    function isAtRisk(address trader) external view returns (bool) {
        uint256 hf = healthFactor(trader);
        return hf >= HEALTH_FACTOR_LIQUIDATION && hf < HEALTH_FACTOR_WARNING;
    }
}
