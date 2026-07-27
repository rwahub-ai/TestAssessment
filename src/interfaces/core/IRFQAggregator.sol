// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRFQAggregator {
    struct Quote {
        address source;
        uint256 price;
        uint256 depth;
        uint256 latencyMs;
    }

    function getBestPrice(bytes32 marketId, bool isBuy, uint256 size) external view returns (uint256 price);
    function getMarkPrice(bytes32 marketId) external view returns (uint256 price);
    function getAllQuotes(bytes32 marketId, bool isBuy, uint256 size) external view returns (Quote[] memory);
    function addSource(address source, string calldata name) external;
    function removeSource(address source) external;
}
