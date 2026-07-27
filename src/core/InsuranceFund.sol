// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


    function requestWithdrawal(uint256 shares) external {
        require(shares > 0 && shares <= sharesOf[msg.sender], "InsuranceFund: bad shares");
        pendingWithdrawShares[msg.sender] = shares;
        withdrawUnlockAt[msg.sender] = block.timestamp + WITHDRAWAL_COOLDOWN;
        emit WithdrawRequested(msg.sender, shares, withdrawUnlockAt[msg.sender]);
    }

    function withdraw() external nonReentrant returns (uint256 amount) {
        uint256 shares = pendingWithdrawShares[msg.sender];
        require(shares > 0, "InsuranceFund: no pending withdrawal");
        require(block.timestamp >= withdrawUnlockAt[msg.sender], "InsuranceFund: cooldown active");
        require(shares <= sharesOf[msg.sender], "InsuranceFund: insufficient shares");

        amount = (shares * totalAssets) / totalShares;

        sharesOf[msg.sender] -= shares;
        totalShares -= shares;
        totalAssets -= amount;
        pendingWithdrawShares[msg.sender] = 0;
        withdrawUnlockAt[msg.sender] = 0;

        collateralToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, shares);
    }

    // ─── VariationalPro-only flows ─────────────────────────────────────────

    function socializeLoss(uint256 amount, bytes32 marketId, uint256 positionId) external onlyVariationalPro {
        require(amount <= totalAssets, "InsuranceFund: exceeds fund");
        totalAssets -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
        emit LossSocialized(amount, marketId, positionId);
    }

    function receiveFee(uint256 amount, bytes32 marketId) external onlyVariationalPro {
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        totalAssets += amount;
        emit FeeReceived(amount, marketId);
    }

    // ─── Views ──────────────────────────────────────────────────────

    function sharePrice() public view returns (uint256) {
        if (totalShares == 0) return PRECISION;
        return (totalAssets * PRECISION) / totalShares;
    }

    function balanceOf(address depositor) external view returns (uint256 shares, uint256 assets) {
        shares = sharesOf[depositor];
        assets = totalShares == 0 ? 0 : (shares * totalAssets) / totalShares;
    }

    /// @notice True while the fund holds a non-trivial balance; a lightweight
    ///         health signal frontends can poll before allowing new leverage.
    function isHealthy() external view returns (bool) {
        return totalAssets > 0;
    }
}
