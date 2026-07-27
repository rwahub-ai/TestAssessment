// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/core/IPriceOracle.sol";

interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

/**
 * @title ChainlinkAdapter
 * @notice Normalizes Chainlink price feeds to the 18-decimal format PriceOracle
 *         expects, and enforces a staleness bound so a frozen feed can't be
 *         used to mark positions.
 */
contract ChainlinkAdapter is Ownable {
    mapping(bytes32 => address) public feeds;
    uint256 public maxStaleness = 1 hours;

    event FeedSet(bytes32 indexed marketId, address feed);

    constructor() Ownable(msg.sender) {}

    function setFeed(bytes32 marketId, address feed) external onlyOwner {
        feeds[marketId] = feed;
        emit FeedSet(marketId, feed);
    }

    function setMaxStaleness(uint256 seconds_) external onlyOwner {
        maxStaleness = seconds_;
    }

    function getPrice(bytes32 marketId) external view returns (uint256 price, uint256 updatedAt) {
        address feed = feeds[marketId];
        require(feed != address(0), "no feed");

        AggregatorV3Interface agg = AggregatorV3Interface(feed);
        (, int256 answer, , uint256 lastUpdated, ) = agg.latestRoundData();
        require(answer > 0, "bad price");
        require(block.timestamp - lastUpdated <= maxStaleness, "stale price");

        uint8 dec = agg.decimals();
        price = dec < 18 ? uint256(answer) * (10 ** (18 - dec)) : uint256(answer) / (10 ** (dec - 18));
        updatedAt = lastUpdated;
    }
}
