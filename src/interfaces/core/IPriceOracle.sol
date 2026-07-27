// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPriceOracle {
    struct PriceData {
        uint256 price;      // 18 decimals
        uint256 updatedAt;
        uint256 confidence;  // bps width of the aggregated confidence interval
    }

    event PriceReported(bytes32 indexed marketId, address indexed reporter, uint256 price);
    event PriceFinalized(bytes32 indexed marketId, uint256 price, uint256 confidence);
    event ReporterUpdated(address indexed reporter, bool active);
    event StalenessThresholdUpdated(uint256 seconds_);

    function reportPrice(bytes32 marketId, uint256 price) external;
    function finalize(bytes32 marketId) external returns (uint256 price);

    function getPrice(bytes32 marketId) external view returns (uint256 price, uint256 updatedAt);
    function isStale(bytes32 marketId) external view returns (bool);
    function twap(bytes32 marketId, uint256 window) external view returns (uint256);
}
