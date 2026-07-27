// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/core/IPriceOracle.sol";



    constructor(address _owner) Ownable(_owner) {}

    // ─── Admin ──────────────────────────────────────────────────────

    function setReporter(address reporter, bool active) external onlyOwner {
        if (active && !isReporter[reporter]) {
            require(reporters.length < MAX_REPORTERS, "Oracle: too many reporters");
            reporters.push(reporter);
        }
        isReporter[reporter] = active;
        emit ReporterUpdated(reporter, active);
    }

    function setStalenessThreshold(uint256 seconds_) external onlyOwner {
        stalenessThreshold = seconds_;
        emit StalenessThresholdUpdated(seconds_);
    }

    // ─── Reporting ──────────────────────────────────────────────────

    function reportPrice(bytes32 marketId, uint256 price) external onlyReporter {
        require(price > 0, "Oracle: zero price");
        if (roundPrices[marketId][msg.sender] == 0) {
            roundReporters[marketId].push(msg.sender);
        }
        roundPrices[marketId][msg.sender] = price;
        emit PriceReported(marketId, msg.sender, price);
    }

    /// @notice Finalizes the current round by taking the median of all
    ///         submitted reporter prices, then clears the round.
    function finalize(bytes32 marketId) external returns (uint256 price) {
        address[] storage roundList = roundReporters[marketId];
        uint256 n = roundList.length;
        require(n > 0, "Oracle: no reports");

        uint256[] memory prices = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            prices[i] = roundPrices[marketId][roundList[i]];
        }
        _sort(prices);
        price = n % 2 == 1 ? prices[n / 2] : (prices[n / 2 - 1] + prices[n / 2]) / 2;

        // confidence = spread between min and max as bps of median
        uint256 confidence = price == 0 ? 0 : ((prices[n - 1] - prices[0]) * 10_000) / price;

        latest[marketId] = PriceData({ price: price, updatedAt: block.timestamp, confidence: confidence });

        Checkpoint[] storage h = history[marketId];
        if (h.length >= MAX_HISTORY) {
            for (uint256 i = 1; i < h.length; i++) {
                h[i - 1] = h[i];
            }
            h.pop();
        }
        h.push(Checkpoint({ price: price, timestamp: block.timestamp }));

        // clear round
        for (uint256 i = 0; i < n; i++) {
            roundPrices[marketId][roundList[i]] = 0;
        }
        delete roundReporters[marketId];

        emit PriceFinalized(marketId, price, confidence);
    }

    // ─── Views ──────────────────────────────────────────────────────

    function getPrice(bytes32 marketId) external view returns (uint256 price, uint256 updatedAt) {
        PriceData memory d = latest[marketId];
        return (d.price, d.updatedAt);
    }

    function isStale(bytes32 marketId) external view returns (bool) {
        PriceData memory d = latest[marketId];
        if (d.updatedAt == 0) return true;
        return block.timestamp - d.updatedAt > stalenessThreshold;
    }

    /// @notice Simple checkpoint-average TWAP over the trailing `window` seconds.
    function twap(bytes32 marketId, uint256 window) external view returns (uint256) {
        Checkpoint[] storage h = history[marketId];
        if (h.length == 0) return 0;

        uint256 cutoff = block.timestamp > window ? block.timestamp - window : 0;
        uint256 sum;
        uint256 count;
        for (uint256 i = h.length; i > 0; i--) {
            Checkpoint storage c = h[i - 1];
            if (c.timestamp < cutoff) break;
            sum += c.price;
            count++;
        }
        if (count == 0) return h[h.length - 1].price;
        return sum / count;
    }

    function reporterCount() external view returns (uint256) {
        return reporters.length;
    }

    // ─── Internal ───────────────────────────────────────────────────

    function _sort(uint256[] memory arr) private pure {
        uint256 n = arr.length;
        for (uint256 i = 1; i < n; i++) {
            uint256 key = arr[i];
            uint256 j = i;
            while (j > 0 && arr[j - 1] > key) {
                arr[j] = arr[j - 1];
                j--;
            }
            arr[j] = key;
        }
    }
}
