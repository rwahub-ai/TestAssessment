// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/governance/IVariationalGovernor.sol";
import "../interfaces/token/IVARStaking.sol";
import "./VariationalTimelock.sol";

/**
 * @title VariationalGovernor
 * @notice On-chain governance for the Variational protocol. Voting power is
 *         derived from boosted $VAR staked in VARStaking (locking longer = more
 *         weight), so governance influence is aligned with long-term commitment
 *         rather than raw token balance alone.
 *
 *         Lifecycle: propose -> (voting delay) -> Active -> Succeeded/Defeated
 *                    -> queue (Timelock) -> execute
 */
contract VariationalGovernor is IVariationalGovernor {
    uint8 public constant SUPPORT_AGAINST = 0;
    uint8 public constant SUPPORT_FOR     = 1;
    uint8 public constant SUPPORT_ABSTAIN = 2;

    IVARStaking  public immutable staking;
    VariationalTimelock public immutable timelock;

    uint256 public votingDelay   = 1 hours;     // delay before voting starts
    uint256 public votingPeriod  = 3 days;      // length of the voting window
    uint256 public proposalThreshold = 50_000e18; // min voting power to propose
    uint256 public quorumVotes   = 2_000_000e18;  // min total votes for a proposal to be valid

    uint256 public override proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool))   public hasVoted;
    mapping(uint256 => mapping(address => uint8))  public voteChoice;

    constructor(address _staking, address _timelock) {
        staking = IVARStaking(_staking);
        timelock = VariationalTimelock(payable(_timelock));
    }

    // ── Proposing ────────────────────────────────────────────────────
    function propose(string calldata title, string calldata description, address target, bytes calldata callData)
        external override returns (uint256 proposalId)
    {
        require(staking.votingPower(msg.sender) >= proposalThreshold, "Governor: below threshold");
        require(bytes(title).length > 0, "Governor: empty title");

        proposalId = ++proposalCount;
        uint256 start = block.timestamp + votingDelay;
        uint256 end = start + votingPeriod;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            target: target,
            callData: callData,
            startTime: start,
            endTime: end,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            eta: 0,
            executed: false,
            cancelled: false
        });

        emit ProposalCreated(proposalId, msg.sender, title, start, end);
    }

    // ── Voting ───────────────────────────────────────────────────────
    function castVote(uint256 proposalId, uint8 support) external override {
        _castVote(msg.sender, proposalId, support, "");
    }

    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external override {
        _castVote(msg.sender, proposalId, support, reason);
    }

    function _castVote(address voter, uint256 proposalId, uint8 support, string memory reason) internal {
        require(state(proposalId) == ProposalState.Active, "Governor: voting closed");
        require(!hasVoted[proposalId][voter], "Governor: already voted");
        require(support <= SUPPORT_ABSTAIN, "Governor: invalid support");

        uint256 weight = staking.votingPower(voter);
        require(weight > 0, "Governor: no voting power");

        Proposal storage p = proposals[proposalId];
        if (support == SUPPORT_FOR) p.forVotes += weight;
        else if (support == SUPPORT_AGAINST) p.againstVotes += weight;
        else p.abstainVotes += weight;

        hasVoted[proposalId][voter] = true;
        voteChoice[proposalId][voter] = support;

        emit VoteCast(voter, proposalId, support, weight, reason);
    }

    // ── Queueing & execution ─────────────────────────────────────────
    function queue(uint256 proposalId) external override {
        require(state(proposalId) == ProposalState.Succeeded, "Governor: not succeeded");
        Proposal storage p = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        p.eta = eta;
        timelock.queueTransaction(p.target, 0, p.callData, eta);
        emit ProposalQueued(proposalId, eta);
    }

    function execute(uint256 proposalId) external payable override {
        require(state(proposalId) == ProposalState.Queued, "Governor: not queued");
        Proposal storage p = proposals[proposalId];
        p.executed = true;
        timelock.executeTransaction{ value: msg.value }(p.target, 0, p.callData, p.eta);
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external override {
        Proposal storage p = proposals[proposalId];
        require(msg.sender == p.proposer, "Governor: not proposer");
        require(!p.executed, "Governor: already executed");
        p.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    // ── Views ────────────────────────────────────────────────────────
    function state(uint256 proposalId) public view override returns (ProposalState) {
        Proposal storage p = proposals[proposalId];
        require(p.id != 0, "Governor: unknown proposal");

        if (p.cancelled) return ProposalState.Cancelled;
        if (p.executed) return ProposalState.Executed;
        if (block.timestamp < p.startTime) return ProposalState.Pending;
        if (block.timestamp <= p.endTime) return ProposalState.Active;

        uint256 totalVotes = p.forVotes + p.againstVotes + p.abstainVotes;
        bool quorumReached = totalVotes >= quorumVotes;
        bool approved = p.forVotes > p.againstVotes;

        if (!quorumReached || !approved) return ProposalState.Defeated;
        if (p.eta == 0) return ProposalState.Succeeded;
        return ProposalState.Queued;
    }

    function getProposal(uint256 proposalId) external view override returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (bool voted, uint8 support) {
        return (hasVoted[proposalId][voter], voteChoice[proposalId][voter]);
    }
}
