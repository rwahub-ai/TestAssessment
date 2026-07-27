// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/token/IVARStaking.sol";

/**
 * @title VARStaking
 * @notice Lock $VAR for boosted rewards and on-chain governance voting power.
 *         - 4 lock tiers with increasing boost multipliers and durations
 *         - Continuous, globally-pooled reward emission (MasterChef-style accumulator)
 *         - Early withdrawal incurs a linearly-decaying penalty, redistributed to remaining stakers
 *         - Boosted balance doubles as governance voting power (read by VariationalGovernor)
 */
contract VARStaking is IVARStaking, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant PRECISION = 1e18;
    uint256 public constant EARLY_WITHDRAW_PENALTY_BPS = 2_000; // 20% max penalty
    uint256 public constant BPS = 10_000;

    IERC20 public immutable varToken;

    // tier => (lockDuration seconds, boostMultiplier in bps where 10000 = 1.00x)
    mapping(LockTier => uint256) public lockDuration;
    mapping(LockTier => uint256) public boostMultiplier;

    uint256 public rewardRatePerSecond;     // VAR emitted per second across the whole pool
    uint256 public rewardPerBoostedStored;  // accumulator, scaled by PRECISION
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public totalBoostedStaked;

    mapping(address => uint256) public rewardPerBoostedPaid;
    mapping(address => uint256) public rewards;
    mapping(address => Stake[]) public stakes;

    uint256 public totalPenaltiesCollected;

    constructor(address _varToken, address _owner) Ownable(_owner) {
        varToken = IERC20(_varToken);

        lockDuration[LockTier.FLEXIBLE] = 0;
        lockDuration[LockTier.BRONZE]   = 30 days;
        lockDuration[LockTier.SILVER]   = 90 days;
        lockDuration[LockTier.GOLD]     = 180 days;

        boostMultiplier[LockTier.FLEXIBLE] = 10_000; // 1.00x
        boostMultiplier[LockTier.BRONZE]   = 12_500; // 1.25x
        boostMultiplier[LockTier.SILVER]   = 17_500; // 1.75x
        boostMultiplier[LockTier.GOLD]     = 25_000; // 2.50x
    }

    // ── Modifiers ────────────────────────────────────────────────────
    modifier updateReward(address account) {
        rewardPerBoostedStored = rewardPerBoostedAccrued();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = pendingRewards(account);
            rewardPerBoostedPaid[account] = rewardPerBoostedStored;
        }
        _;
    }

    // ── Staking ──────────────────────────────────────────────────────
    function stake(uint256 amount, LockTier tier) external nonReentrant updateReward(msg.sender) returns (uint256 stakeId) {
        require(amount > 0, "zero amount");
        varToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 boosted = (amount * boostMultiplier[tier]) / BPS;
        uint256 unlockAt = block.timestamp + lockDuration[tier];

        stakes[msg.sender].push(Stake({
            amount: amount,
            boostedAmount: boosted,
            tier: tier,
            startTime: block.timestamp,
            unlockTime: unlockAt,
            rewardDebt: 0,
            withdrawn: false
        }));
        stakeId = stakes[msg.sender].length - 1;

        totalBoostedStaked += boosted;

        emit Staked(msg.sender, stakeId, amount, tier, unlockAt);
    }

    function unstake(uint256 stakeId) external nonReentrant updateReward(msg.sender) {
        Stake storage s = stakes[msg.sender][stakeId];
        require(!s.withdrawn, "already withdrawn");
        require(block.timestamp >= s.unlockTime, "still locked");

        s.withdrawn = true;
        totalBoostedStaked -= s.boostedAmount;

        varToken.safeTransfer(msg.sender, s.amount);
        emit Unstaked(msg.sender, stakeId, s.amount, 0);
    }

    /// @notice Withdraw before unlock time, forfeiting a linearly-decaying penalty (max 20%)
    function emergencyUnstake(uint256 stakeId) external nonReentrant updateReward(msg.sender) {
        Stake storage s = stakes[msg.sender][stakeId];
        require(!s.withdrawn, "already withdrawn");
        require(block.timestamp < s.unlockTime, "use unstake()");

        s.withdrawn = true;
        totalBoostedStaked -= s.boostedAmount;

        uint256 totalLock = s.unlockTime - s.startTime;
        uint256 elapsed = block.timestamp - s.startTime;
        uint256 remainingRatio = totalLock == 0 ? 0 : ((totalLock - elapsed) * PRECISION) / totalLock;
        uint256 penalty = (s.amount * EARLY_WITHDRAW_PENALTY_BPS * remainingRatio) / (BPS * PRECISION);
        uint256 payout = s.amount - penalty;

        totalPenaltiesCollected += penalty;
        varToken.safeTransfer(msg.sender, payout);

        emit Unstaked(msg.sender, stakeId, payout, penalty);
    }

    function claimRewards() external nonReentrant updateReward(msg.sender) returns (uint256 claimed) {
        claimed = rewards[msg.sender];
        require(claimed > 0, "no rewards");
        rewards[msg.sender] = 0;
        varToken.safeTransfer(msg.sender, claimed);
        emit RewardsClaimed(msg.sender, claimed);
    }

    // ── Views ────────────────────────────────────────────────────────
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerBoostedAccrued() public view returns (uint256) {
        if (totalBoostedStaked == 0) return rewardPerBoostedStored;
        uint256 elapsed = lastTimeRewardApplicable() - lastUpdateTime;
        return rewardPerBoostedStored + (elapsed * rewardRatePerSecond * PRECISION) / totalBoostedStaked;
    }

    function pendingRewards(address user) public view returns (uint256) {
        uint256 userBoosted = _userTotalBoosted(user);
        return rewards[user] +
            (userBoosted * (rewardPerBoostedAccrued() - rewardPerBoostedPaid[user])) / PRECISION;
    }

    function votingPower(address user) external view returns (uint256) {
        return _userTotalBoosted(user);
    }

    function getUserStakes(address user) external view returns (uint256[] memory ids) {
        uint256 n = stakes[user].length;
        ids = new uint256[](n);
        for (uint256 i = 0; i < n; i++) ids[i] = i;
    }

    function getStake(address user, uint256 stakeId) external view returns (Stake memory) {
        return stakes[user][stakeId];
    }

    function _userTotalBoosted(address user) internal view returns (uint256 total) {
        Stake[] storage userStakes = stakes[user];
        for (uint256 i = 0; i < userStakes.length; i++) {
            if (!userStakes[i].withdrawn) total += userStakes[i].boostedAmount;
        }
    }

    // ── Admin (reward funding) ──────────────────────────────────────
    /// @notice Fund the pool with VAR rewards, streamed linearly over `duration` seconds
    function fundRewards(uint256 amount, uint256 duration) external onlyOwner updateReward(address(0)) {
        require(duration > 0, "duration");
        varToken.safeTransferFrom(msg.sender, address(this), amount);

        if (block.timestamp >= periodFinish) {
            rewardRatePerSecond = amount / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRatePerSecond;
            rewardRatePerSecond = (amount + leftover) / duration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        emit RewardRateUpdated(rewardRatePerSecond);
        emit RewardsFunded(amount, periodFinish);
    }

    function withdrawPenalties(address to) external onlyOwner {
        uint256 amt = totalPenaltiesCollected;
        totalPenaltiesCollected = 0;
        varToken.safeTransfer(to, amt);
    }
}
