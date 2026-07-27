// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVariationalPro {
    // ─────────────────────────────────────────────────────────────────
    // Structs
    // ─────────────────────────────────────────────────────────────────

    struct Position {
        uint256  id;
        address  trader;
        bytes32  marketId;
        bool     isLong;
        uint256  size;          // Notional size in USDC (6 decimals)
        uint256  margin;        // Collateral locked (6 decimals)
        uint256  leverage;      // e.g. 10 = 10x
        uint256  entryPrice;    // Price at open (18 decimals)
        uint256  entryFundingIdx;
        uint256  openTimestamp;
        bool     isOpen;
    }

    struct Market {
        bytes32 id;
        string  symbol;
        uint256 maxLeverage;
        bool    isActive;
    }

    struct FundingRate {
        int256  rate;       // Hourly rate in bps (can be negative)
        uint256 timestamp;
    }

    struct RFQQuote {
        address source;
        uint256 price;
        uint256 depth;
        uint256 latencyMs;
        bool    available;
    }

    // ─────────────────────────────────────────────────────────────────
    // Function signatures
    // ─────────────────────────────────────────────────────────────────

    function depositCollateral(uint256 amount) external;
    function withdrawCollateral(uint256 amount) external;

    function openPosition(
        bytes32 marketId,
        bool    isLong,
        uint256 size,
        uint256 leverage,
        uint256 maxPrice
    ) external returns (uint256 positionId);

    function closePosition(uint256 positionId, uint256 minPrice)
        external returns (int256 pnl);

    function addMargin(uint256 positionId, uint256 amount) external;
    function liquidate(uint256 positionId) external;

    function getPosition(uint256 positionId) external view returns (Position memory);
    function getUserPositions(address user) external view returns (uint256[] memory);
    function getUnrealizedPnL(uint256 positionId) external view returns (int256);
    function getLiquidationPrice(uint256 positionId) external view returns (uint256);
    function availableCollateral(address user) external view returns (uint256);
}
