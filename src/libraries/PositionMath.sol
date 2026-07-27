// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/core/IVariationalPro.sol";

library PositionMath {
    uint256 constant BPS = 10_000;

    function liquidationPrice(IVariationalPro.Position memory pos) internal pure returns (uint256) {
        uint256 mmRatio = 50;
        if (pos.isLong) {
            uint256 drop = (pos.entryPrice * (BPS / pos.leverage - mmRatio)) / BPS;
            return pos.entryPrice > drop ? pos.entryPrice - drop : 0;
        } else {
            uint256 rise = (pos.entryPrice * (BPS / pos.leverage - mmRatio)) / BPS;
            return pos.entryPrice + rise;
        }
    }

    function calculatePnL(IVariationalPro.Position memory pos, uint256 exitPrice) internal pure returns (int256) {
        if (pos.isLong) {
            int256 delta = int256(exitPrice) - int256(pos.entryPrice);
            return (delta * int256(pos.size)) / int256(pos.entryPrice);
        } else {
            int256 delta = int256(pos.entryPrice) - int256(exitPrice);
            return (delta * int256(pos.size)) / int256(pos.entryPrice);
        }
    }

    function isUndercollateralized(IVariationalPro.Position memory pos, uint256 markPrice) internal pure returns (bool) {
        uint256 liqPx = liquidationPrice(pos);
        return pos.isLong ? markPrice <= liqPx : markPrice >= liqPx;
    }
}
