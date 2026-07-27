// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Multicall
 * @notice Batches multiple read-only calls into a single RPC round trip —
 *         the frontend uses this to fetch e.g. every market's price, a
 *         user's balance across several tokens, and staking/governance
 *         state in one call instead of one-request-per-field. Standard
 *         infrastructure piece, deployed once and reused by all frontend
 *         reads via wagmi's `useReadContracts` batching.
 */
contract Multicall {
    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Executes every call; reverts the whole batch if any call fails.
    function aggregate(Call[] calldata calls) external view returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.staticcall(calls[i].callData);
            require(success, "Multicall: call failed");
            returnData[i] = ret;
        }
    }

    /// @notice Like `aggregate`, but returns per-call success instead of reverting the batch.
    function tryAggregate(bool requireSuccess, Call[] calldata calls) external view returns (Result[] memory results) {
        results = new Result[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.staticcall(calls[i].callData);
            if (requireSuccess) {
                require(success, "Multicall: call failed");
            }
            results[i] = Result({ success: success, returnData: ret });
        }
    }

    function getBlockNumber() external view returns (uint256) {
        return block.number;
    }

    function getCurrentBlockTimestamp() external view returns (uint256) {
        return block.timestamp;
    }
}
