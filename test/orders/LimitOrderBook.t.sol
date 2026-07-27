// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/orders/LimitOrderBook.sol";

contract LimitOrderBookTest is Test {
    LimitOrderBook book;
    address trader = address(0xCAFE);

    function setUp() public {
        book = new LimitOrderBook();
    }

    function testPlaceOrder() public {
        vm.prank(trader);
        uint256 id = book.placeOrder(bytes32("BTC-USD"), ILimitOrderBook.OrderType.LIMIT, true, 1000e6, 60000e18, 5, 0);
        ILimitOrderBook.Order memory o = book.getOrder(id);
        assertEq(o.trader, trader);
        assertEq(uint8(o.status), uint8(ILimitOrderBook.OrderStatus.OPEN));
    }

    function testCancelOrder() public {
        vm.startPrank(trader);
        uint256 id = book.placeOrder(bytes32("BTC-USD"), ILimitOrderBook.OrderType.STOP_LOSS, false, 500e6, 50000e18, 2, 0);
        book.cancelOrder(id);
        vm.stopPrank();
        ILimitOrderBook.Order memory o = book.getOrder(id);
        assertEq(uint8(o.status), uint8(ILimitOrderBook.OrderStatus.CANCELLED));
    }

    function testKeeperFill() public {
        vm.prank(trader);
        uint256 id = book.placeOrder(bytes32("ETH-USD"), ILimitOrderBook.OrderType.TAKE_PROFIT, true, 200e6, 3000e18, 10, 0);
        book.setKeeper(address(this), true);
        book.fillOrder(id, 3000e18);
        ILimitOrderBook.Order memory o = book.getOrder(id);
        assertEq(uint8(o.status), uint8(ILimitOrderBook.OrderStatus.FILLED));
    }
}
