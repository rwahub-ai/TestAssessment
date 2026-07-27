// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILimitOrderBook {
    enum OrderType { LIMIT, STOP_LOSS, TAKE_PROFIT }
    enum OrderStatus { OPEN, FILLED, CANCELLED, EXPIRED }

    struct Order {
        uint256   id;
        address   trader;
        bytes32   marketId;
        OrderType orderType;
        bool      isLong;
        uint256   size;
        uint256   triggerPrice;
        uint256   leverage;
        uint256   createdAt;
        uint256   expiresAt;
        OrderStatus status;
    }

    event OrderPlaced(uint256 indexed id, address indexed trader, bytes32 indexed marketId, OrderType orderType);
    event OrderCancelled(uint256 indexed id);
    event OrderFilled(uint256 indexed id, uint256 fillPrice);

    function placeOrder(bytes32 marketId, OrderType orderType, bool isLong, uint256 size, uint256 triggerPrice, uint256 leverage, uint256 expiresAt) external returns (uint256);
    function cancelOrder(uint256 orderId) external;
    function getOrder(uint256 orderId) external view returns (Order memory);
}
