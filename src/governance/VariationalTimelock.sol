// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title VariationalTimelock
 * @notice Minimal Compound-style timelock. The VariationalGovernor queues successful
 *         proposals here; execution can only happen after `delay` has elapsed,
 *         giving token holders a window to exit if they disagree with a passed
 *         proposal. Only the governor (or, transitively, governance itself via
 *         a future `setAdmin` proposal) may queue/execute/cancel transactions.
 */
contract VariationalTimelock {
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;

    address public admin;       // the VariationalGovernor contract
    address public pendingAdmin;
    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 newDelay);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: not admin");
        _;
    }

    constructor(address _admin, uint256 _delay) {
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY, "Timelock: invalid delay");
        admin = _admin;
        delay = _delay;
    }

    function setDelay(uint256 _delay) external onlyAdmin {
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY, "Timelock: invalid delay");
        delay = _delay;
        emit NewDelay(_delay);
    }

    function setPendingAdmin(address _pendingAdmin) external onlyAdmin {
        pendingAdmin = _pendingAdmin;
        emit NewPendingAdmin(_pendingAdmin);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Timelock: not pending admin");
        admin = msg.sender;
        pendingAdmin = address(0);
        emit NewAdmin(admin);
    }

    function queueTransaction(address target, uint256 value, bytes calldata data, uint256 eta)
        external onlyAdmin returns (bytes32 txHash)
    {
        require(eta >= block.timestamp + delay, "Timelock: eta too soon");
        txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, data, eta);
    }

    function cancelTransaction(address target, uint256 value, bytes calldata data, uint256 eta)
        external onlyAdmin
    {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, data, eta);
    }

    function executeTransaction(address target, uint256 value, bytes calldata data, uint256 eta)
        external payable onlyAdmin returns (bytes memory)
    {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        require(queuedTransactions[txHash], "Timelock: not queued");
        require(block.timestamp >= eta, "Timelock: still locked");
        require(block.timestamp <= eta + GRACE_PERIOD, "Timelock: stale transaction");

        queuedTransactions[txHash] = false;

        (bool success, bytes memory returnData) = target.call{ value: value }(data);
        require(success, "Timelock: execution reverted");

        emit ExecuteTransaction(txHash, target, value, data, eta);
        return returnData;
    }

    receive() external payable {}
}
