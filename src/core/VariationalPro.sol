// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/core/IVariationalPro.sol";
import "../interfaces/core/IRFQAggregator.sol";
import "../libraries/PositionMath.sol";

/**
 * @title VariationalPro
 * @notice Variational Pro — perpetuals and derivatives with RFQ execution,
 *         isolated escrow settlement, zero trading fees, gasless UX on Arbitrum.
 */
contract VariationalPro is IVariationalPro, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using PositionMath for Position;

    // ── Constants ────────────────────────────────────────────────────
    uint256 public constant MAX_LEVERAGE    = 50;
    uint256 public constant MIN_MARGIN      = 10e6;     // 10 USDC
    uint256 public constant LIQUIDATION_FEE = 50;       // 0.5% bps
    uint256 public constant BPS             = 10_000;

    // ── State ────────────────────────────────────────────────────────
    IERC20           public immutable usdc;
    IRFQAggregator   public rfqAggregator;

    uint256 public nextPositionId;
    uint256 public totalOpenInterest;
    uint256 public protocolRevenue;

    mapping(uint256 => Position)        public positions;
    mapping(address => uint256[])       public userPositions;
    mapping(bytes32 => Market)          public markets;
    mapping(bytes32 => bool)            public marketActive;
    mapping(address => uint256)         public collateralBalance;
    mapping(bytes32 => uint256)         public fundingIndex;
    mapping(bytes32 => uint256)         public lastFundingTime;
    mapping(bytes32 => FundingRate)     public fundingRates;
    mapping(uint256 => uint256)         public escrow;

    bytes32[] public activeMarkets;

    // ── Events ───────────────────────────────────────────────────────
    event PositionOpened(uint256 indexed id, address indexed trader, bytes32 indexed market, bool isLong, uint256 size, uint256 price, uint256 leverage);
    event PositionClosed(uint256 indexed id, address indexed trader, int256 pnl, uint256 exitPrice);
    event PositionLiquidated(uint256 indexed id, address indexed liquidator, uint256 liqPrice, uint256 fee);
    event MarginAdded(uint256 indexed id, uint256 amount);
    event FundingSettled(bytes32 indexed market, uint256 rate, uint256 ts);
    event MarketAdded(bytes32 indexed market, string symbol);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);

    // ── Constructor ──────────────────────────────────────────────────
    constructor(address _usdc, address _rfq, address _owner) Ownable(_owner) {
        usdc = IERC20(_usdc);
        rfqAggregator = IRFQAggregator(_rfq);
    }

    // ── Collateral ───────────────────────────────────────────────────
    function depositCollateral(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "zero");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        collateralBalance[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(amount <= collateralBalance[msg.sender], "insufficient");
        collateralBalance[msg.sender] -= amount;
        usdc.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    // ── Positions ────────────────────────────────────────────────────
    function openPosition(bytes32 marketId, bool isLong, uint256 size, uint256 leverage, uint256 maxPrice)
        external nonReentrant whenNotPaused returns (uint256 positionId)
    {
        require(marketActive[marketId], "inactive");
        require(leverage >= 1 && leverage <= MAX_LEVERAGE, "leverage");
        require(size > 0, "zero size");

        uint256 margin = size / leverage;
        require(margin >= MIN_MARGIN, "min margin");
        require(collateralBalance[msg.sender] >= margin, "collateral");

        _settleFunding(marketId);

        uint256 fillPrice = rfqAggregator.getBestPrice(marketId, isLong, size);
        if (isLong)  require(fillPrice <= maxPrice, "slippage");
        else         require(fillPrice >= maxPrice, "slippage");

        collateralBalance[msg.sender] -= margin;
        positionId = ++nextPositionId;
        escrow[positionId] = margin;

        positions[positionId] = Position({
            id:              positionId,
            trader:          msg.sender,
            marketId:        marketId,
            isLong:          isLong,
            size:            size,
            margin:          margin,
            leverage:        leverage,
            entryPrice:      fillPrice,
            entryFundingIdx: fundingIndex[marketId],
            openTimestamp:   block.timestamp,
            isOpen:          true
        });

        userPositions[msg.sender].push(positionId);
        totalOpenInterest += size;

        emit PositionOpened(positionId, msg.sender, marketId, isLong, size, fillPrice, leverage);
    }

    function closePosition(uint256 positionId, uint256 minPrice)
        external nonReentrant returns (int256 pnl)
    {
        Position storage pos = positions[positionId];
        require(pos.isOpen && pos.trader == msg.sender, "unauthorized");

        _settleFunding(pos.marketId);

        uint256 exitPrice = rfqAggregator.getBestPrice(pos.marketId, !pos.isLong, pos.size);
        if (pos.isLong) require(exitPrice >= minPrice, "slippage");
        else            require(exitPrice <= minPrice, "slippage");

        pnl = PositionMath.calculatePnL(pos, exitPrice);

        uint256 escrowed  = escrow[positionId];
        int256  settle    = int256(escrowed) + pnl;
        uint256 toReturn  = settle > 0 ? uint256(settle) : 0;

        pos.isOpen = false;
        escrow[positionId] = 0;
        totalOpenInterest -= pos.size;

        if (toReturn > 0) collateralBalance[msg.sender] += toReturn;

        emit PositionClosed(positionId, msg.sender, pnl, exitPrice);
    }

    function addMargin(uint256 positionId, uint256 amount) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isOpen && pos.trader == msg.sender, "unauthorized");
        require(collateralBalance[msg.sender] >= amount, "collateral");
        collateralBalance[msg.sender] -= amount;
        pos.margin += amount;
        escrow[positionId] += amount;
        emit MarginAdded(positionId, amount);
    }

    function liquidate(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isOpen, "not open");

        uint256 markPrice = rfqAggregator.getMarkPrice(pos.marketId);
        require(PositionMath.isUndercollateralized(pos, markPrice), "healthy");

        _settleFunding(pos.marketId);

        uint256 escrowed  = escrow[positionId];
        uint256 liqFee    = (escrowed * LIQUIDATION_FEE) / BPS;
        uint256 remaining = escrowed > liqFee ? escrowed - liqFee : 0;

        pos.isOpen = false;
        escrow[positionId] = 0;
        totalOpenInterest -= pos.size;
        protocolRevenue += remaining;

        usdc.safeTransfer(msg.sender, liqFee);

        emit PositionLiquidated(positionId, msg.sender, markPrice, liqFee);
    }

    // ── Funding ──────────────────────────────────────────────────────
    function _settleFunding(bytes32 marketId) internal {
        uint256 elapsed = block.timestamp - lastFundingTime[marketId];
        if (elapsed == 0) return;
        FundingRate memory fr = fundingRates[marketId];
        uint256 rate = fr.rate < 0 ? uint256(-fr.rate) : uint256(fr.rate);
        fundingIndex[marketId]    += (rate * elapsed) / 3600;
        lastFundingTime[marketId]  = block.timestamp;
        emit FundingSettled(marketId, rate, block.timestamp);
    }

    // ── Views ────────────────────────────────────────────────────────
    function getPosition(uint256 id) external view returns (Position memory) { return positions[id]; }
    function getUserPositions(address u) external view returns (uint256[] memory) { return userPositions[u]; }
    function availableCollateral(address u) external view returns (uint256) { return collateralBalance[u]; }

    function getUnrealizedPnL(uint256 id) external view returns (int256) {
        Position memory pos = positions[id];
        if (!pos.isOpen) return 0;
        uint256 mark = rfqAggregator.getMarkPrice(pos.marketId);
        return PositionMath.calculatePnL(pos, mark);
    }

    function getLiquidationPrice(uint256 id) external view returns (uint256) {
        return PositionMath.liquidationPrice(positions[id]);
    }

    // ── Admin ────────────────────────────────────────────────────────
    function addMarket(bytes32 id, string calldata sym, uint256 maxLev, int256 fundingRate) external onlyOwner {
        require(!marketActive[id], "exists");
        markets[id] = Market({ id: id, symbol: sym, maxLeverage: maxLev, isActive: true });
        marketActive[id] = true;
        lastFundingTime[id] = block.timestamp;
        fundingRates[id] = FundingRate({ rate: fundingRate, timestamp: block.timestamp });
        activeMarkets.push(id);
        emit MarketAdded(id, sym);
    }

    function updateFundingRate(bytes32 id, int256 rate) external onlyOwner {
        _settleFunding(id);
        fundingRates[id] = FundingRate({ rate: rate, timestamp: block.timestamp });
    }

    function setRFQAggregator(address rfq) external onlyOwner { rfqAggregator = IRFQAggregator(rfq); }

    function withdrawRevenue(address to) external onlyOwner {
        uint256 amt = protocolRevenue;
        protocolRevenue = 0;
        usdc.safeTransfer(to, amt);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
