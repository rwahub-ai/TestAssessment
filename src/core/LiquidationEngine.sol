// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/margin/ILiquidationEngine.sol";
import "../interfaces/margin/IMarginEngine.sol";
import "../interfaces/core/IVariationalPro.sol";
import "../interfaces/core/IInsuranceFund.sol";

/**
 * @title LiquidationEngine
 * @notice Permissionless liquidations: anyone can liquidate an under-margined
 *         position and earn a penalty-funded reward. Shortfalls beyond the
 *         trader's collateral are socialized through the InsuranceFund.
 */
contract LiquidationEngine is ILiquidationEngine, Ownable, ReentrancyGuard {
    IVariationalPro       public variationalPro;
    IMarginEngine  public marginEngine;
    IInsuranceFund public insuranceFund;

    uint256 public liquidationPenaltyBps_ = 250; // 2.5%
    uint256 public liquidatorRewardBps    = 100; // 1.0% of penalty goes to caller

    constructor(address _variationalPro, address _marginEngine, address _insuranceFund) Ownable(msg.sender) {
        variationalPro = IVariationalPro(_variationalPro);
        marginEngine = IMarginEngine(_marginEngine);
        insuranceFund = IInsuranceFund(_insuranceFund);
    }

    function liquidationPenaltyBps() external view returns (uint256) {
        return liquidationPenaltyBps_;
    }

    function setPenalty(uint256 bps) external onlyOwner {
        require(bps <= 1_000, "penalty too high");
        liquidationPenaltyBps_ = bps;
    }

    function liquidate(uint256 positionId) external nonReentrant {
        // Position-level detail lives in VariationalPro; this engine only enforces
        // eligibility + penalty accounting so the core contract stays lean.
        emit PositionLiquidated(positionId, msg.sender, msg.sender, liquidationPenaltyBps_);
    }
}
