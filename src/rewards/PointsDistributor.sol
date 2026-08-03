// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/rewards/IPointsDistributor.sol";

/**
 * @title PointsDistributor
 * @notice Off-chain-scored, on-chain-settled points program. A permissioned
 *         set of keepers credit points to accounts (e.g. after indexing a
 *         day's trading volume or referral activity); points are redeemable
 *         for $VAR at an owner-adjustable rate, funded from a pre-loaded
 *         reward pool rather than minted on demand.
 */
contract PointsDistributor is IPointsDistributor, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable varToken;

    /// @dev Points -> $VAR conversion rate, expressed in bps of 1:1.
    ///      e.g. 100 bps = 1 point redeems for 0.01 VAR (scaled to VAR's
    ///      18 decimals in `previewRedeem` — points themselves are plain,
    ///      un-scaled whole numbers, e.g. "500 points" is credited as the
    ///      literal integer 500, not 500e18).
    uint256 public redemptionRateBps = 100;
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant VAR_DECIMALS_SCALE = 1e18;

    mapping(address => bool) public isKeeper;
    mapping(address => uint256) public pointsOf;
    mapping(address => uint256) public pointsRedeemed;
    uint256 public totalPointsIssued;

    modifier onlyKeeper() {
        require(isKeeper[msg.sender] || msg.sender == owner(), "Points: not a keeper");
        _;
    }

    constructor(address _owner, address _varToken) Ownable(_owner) {
        varToken = IERC20(_varToken);
    }

    // ─── Admin ──────────────────────────────────────────────────────

    function setKeeper(address keeper, bool active) external onlyOwner {
        isKeeper[keeper] = active;
        emit KeeperUpdated(keeper, active);
    }

    function setRedemptionRate(uint256 newRateBps) external onlyOwner {
        require(newRateBps > 0 && newRateBps <= BPS_DENOMINATOR, "Points: bad rate");
        redemptionRateBps = newRateBps;
        emit RedemptionRateUpdated(newRateBps);
    }

    /// @notice Top up the reward pool that backs redemptions.
    function fundPool(uint256 amount) external {
        varToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    // ─── Crediting ──────────────────────────────────────────────────

    function creditPoints(address account, uint256 amount, bytes32 reason) public onlyKeeper {
        require(account != address(0), "Points: zero address");
        require(amount > 0, "Points: zero amount");
        pointsOf[account] += amount;
        totalPointsIssued += amount;
        emit PointsCredited(account, amount, reason);
    }

    function creditPointsBatch(
        address[] calldata accounts,
        uint256[] calldata amounts,
        bytes32 reason
    ) external onlyKeeper {
        require(accounts.length == amounts.length, "Points: length mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            creditPoints(accounts[i], amounts[i], reason);
        }
    }

    // ─── Redemption ─────────────────────────────────────────────────

    function redeem(uint256 points) external nonReentrant returns (uint256 varAmount) {
        require(points > 0 && points <= pointsOf[msg.sender], "Points: insufficient balance");

        varAmount = previewRedeem(points);
        require(varAmount <= varToken.balanceOf(address(this)), "Points: pool depleted");

        pointsOf[msg.sender] -= points;
        pointsRedeemed[msg.sender] += points;

        varToken.safeTransfer(msg.sender, varAmount);
        emit PointsRedeemed(msg.sender, points, varAmount);
    }

    // ─── Views ──────────────────────────────────────────────────────

    function previewRedeem(uint256 points) public view returns (uint256) {
        return (points * redemptionRateBps * VAR_DECIMALS_SCALE) / BPS_DENOMINATOR;
    }
}
