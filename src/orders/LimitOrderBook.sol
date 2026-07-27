// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/orders/ILimitOrderBook.sol";

/**
 * @title LimitOrderBook
 * @notice Off-book conditional order registry for Variational Pro. Traders register
 *         limit / stop-loss / take-profit intents here; a keeper network
 *         watches PriceOracle and calls back into VariationalPro to execute fills
 *         once a trigger condition is met.
 */
contract LimitOrderBook is ILimitOrderBook, Ownable, ReentrancyGuard {
    uint256 private _nextOrderId = 1;
    mapping(uint256 => Order) private _orders;
    mapping(address => uint256[]) public ordersByTrader;
    mapping(address => bool) public keepers;

    modifier onlyKeeper() {
        require(keepers[msg.sender] || msg.sender == owner(), "not keeper");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function setKeeper(address keeper, bool allowed) external onlyOwner {
        keepers[keeper] = allowed;
    }

    function placeOrder(
        bytes32 marketId,
        OrderType orderType,
        bool isLong,
        uint256 size,
        uint256 triggerPrice,
        uint256 leverage,
        uint256 expiresAt
    ) external nonReentrant returns (uint256) {
        require(size > 0, "zero size");
        require(triggerPrice > 0, "zero trigger");

        uint256 id = _nextOrderId++;
        _orders[id] = Order({
            id: id,
            trader: msg.sender,
            marketId: marketId,
            orderType: orderType,
            isLong: isLong,
            size: size,
            triggerPrice: triggerPrice,
            leverage: leverage,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            status: OrderStatus.OPEN
        });
        ordersByTrader[msg.sender].push(id);
        emit OrderPlaced(id, msg.sender, marketId, orderType);
        return id;
    }

    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage o = _orders[orderId];
        require(o.trader == msg.sender, "not owner");
        require(o.status == OrderStatus.OPEN, "not open");
        o.status = OrderStatus.CANCELLED;
        emit OrderCancelled(orderId);
    }

    function fillOrder(uint256 orderId, uint256 fillPrice) external onlyKeeper nonReentrant {
        Order storage o = _orders[orderId];
        require(o.status == OrderStatus.OPEN, "not open");
        if (o.expiresAt != 0 && block.timestamp > o.expiresAt) {
            o.status = OrderStatus.EXPIRED;
            return;
        }
        o.status = OrderStatus.FILLED;
        emit OrderFilled(orderId, fillPrice);
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return _orders[orderId];
    }

    function getOrdersByTrader(address trader) external view returns (uint256[] memory) {
        return ordersByTrader[trader];
    }
}
