// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title VestingVault
 * @notice Linear $VAR vesting with an optional cliff, used for team, advisor,
 *         and investor allocations. Schedules are revocable by the owner
 *         (treasury/multisig) for unvested amounts only — anything already
 *         vested at the time of revocation remains fully claimable.
 */
contract VestingVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 released;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool    revocable;
        bool    revoked;
    }

    IERC20 public immutable varToken;

    uint256 public nextScheduleId;
    mapping(uint256 => VestingSchedule) public schedules;
    mapping(address => uint256[]) public schedulesByBeneficiary;

    event ScheduleCreated(uint256 indexed id, address indexed beneficiary, uint256 amount, uint256 start, uint256 cliff, uint256 duration);
    event TokensReleased(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event ScheduleRevoked(uint256 indexed id, uint256 unvestedReturned);

    constructor(address _varToken, address _owner) Ownable(_owner) {
        varToken = IERC20(_varToken);
    }

    function createSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner returns (uint256 id) {
        require(beneficiary != address(0), "zero beneficiary");
        require(amount > 0, "zero amount");
        require(vestingDuration > 0, "zero duration");
        require(cliffDuration <= vestingDuration, "cliff > duration");

        varToken.safeTransferFrom(msg.sender, address(this), amount);

        id = ++nextScheduleId;
        schedules[id] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: amount,
            released: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });
        schedulesByBeneficiary[beneficiary].push(id);

        emit ScheduleCreated(id, beneficiary, amount, startTime, cliffDuration, vestingDuration);
    }

    function release(uint256 id) external nonReentrant {
        VestingSchedule storage s = schedules[id];
        require(msg.sender == s.beneficiary, "not beneficiary");

        uint256 releasable = releasableAmount(id);
        require(releasable > 0, "nothing to release");

        s.released += releasable;
        varToken.safeTransfer(s.beneficiary, releasable);

        emit TokensReleased(id, s.beneficiary, releasable);
    }

    function revoke(uint256 id) external onlyOwner {
        VestingSchedule storage s = schedules[id];
        require(s.revocable, "not revocable");
        require(!s.revoked, "already revoked");

        uint256 vested = vestedAmount(id);
        uint256 unvested = s.totalAmount - vested;

        s.revoked = true;
        s.totalAmount = vested; // freezes the schedule at its currently-vested amount

        if (unvested > 0) varToken.safeTransfer(owner(), unvested);

        emit ScheduleRevoked(id, unvested);
    }

    // ── Views ────────────────────────────────────────────────────────
    function vestedAmount(uint256 id) public view returns (uint256) {
        VestingSchedule storage s = schedules[id];
        if (s.totalAmount == 0) return 0;
        if (block.timestamp < s.startTime + s.cliffDuration) return 0;
        if (block.timestamp >= s.startTime + s.vestingDuration) return s.totalAmount;
        uint256 elapsed = block.timestamp - s.startTime;
        return (s.totalAmount * elapsed) / s.vestingDuration;
    }

    function releasableAmount(uint256 id) public view returns (uint256) {
        return vestedAmount(id) - schedules[id].released;
    }

    function getSchedulesByBeneficiary(address beneficiary) external view returns (uint256[] memory) {
        return schedulesByBeneficiary[beneficiary];
    }
}
