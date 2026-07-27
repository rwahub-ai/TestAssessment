// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/margin/IMarginEngine.sol";
import "../interfaces/core/IVariationalPro.sol";



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


    function isAtRisk(address trader) external view returns (bool) {
        uint256 hf = healthFactor(trader);
        return hf >= HEALTH_FACTOR_LIQUIDATION && hf < HEALTH_FACTOR_WARNING;
    }
}
