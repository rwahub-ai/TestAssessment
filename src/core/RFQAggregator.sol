// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/core/IRFQAggregator.sol";



    function batchUpdateQuotes(
        bytes32   marketId,
        address[] calldata _sources,
        uint256[] calldata prices
    ) external onlyOwner {
        require(_sources.length == prices.length, "RFQ: length mismatch");
        for (uint256 i = 0; i < _sources.length; i++) {
            if (sources[_sources[i]].active) {
                latestQuotes[marketId][_sources[i]] = prices[i];
            }
        }
    }

    // ─── Price queries ───────────────────────────────────────────────

    function getBestPrice(bytes32 marketId, bool isBuy, uint256 /*size*/)
        external
        view
        override
        returns (uint256 bestPrice)
    {
        bestPrice = isBuy ? type(uint256).max : 0;
        for (uint256 i = 0; i < sourceList.length; i++) {
            address src = sourceList[i];
            if (!sources[src].active) continue;
            uint256 q = latestQuotes[marketId][src];
            if (q == 0) continue;
            if (isBuy  && q < bestPrice) bestPrice = q;
            if (!isBuy && q > bestPrice) bestPrice = q;
        }
        // Fallback to mark price
        if (bestPrice == 0 || bestPrice == type(uint256).max) {
            bestPrice = markPrices[marketId];
        }
    }

    function getMarkPrice(bytes32 marketId) external view override returns (uint256) {
        return markPrices[marketId];
    }

    function getAllQuotes(bytes32 marketId, bool /*isBuy*/, uint256 /*size*/)
        external
        view
        override
        returns (Quote[] memory quotes)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < sourceList.length; i++) {
            if (sources[sourceList[i]].active && latestQuotes[marketId][sourceList[i]] > 0) count++;
        }
        quotes = new Quote[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < sourceList.length; i++) {
            address src = sourceList[i];
            if (!sources[src].active) continue;
            uint256 q = latestQuotes[marketId][src];
            if (q == 0) continue;
            quotes[idx++] = Quote({ source: src, price: q, depth: 1_000_000e6, latencyMs: 15 });
        }
    }

    // ─── Admin ───────────────────────────────────────────────────────

    function addSource(address source, string calldata name) external override onlyOwner {
        require(!sources[source].active, "RFQ: already exists");
        sources[source] = Source({ name: name, active: true, weight: 1 });
        sourceList.push(source);
        emit SourceAdded(source, name);
    }

    function removeSource(address source) external override onlyOwner {
        sources[source].active = false;
        emit SourceRemoved(source);
    }
}
