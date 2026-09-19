// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/VariationalPro.sol";
import "../../src/core/RFQAggregator.sol";
import "../../src/token/VARToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 10_000_000e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract VariationalProTest is Test {
    VariationalPro public pro;
    RFQAggregator public rfq;
    MockUSDC public usdc;

    address owner = address(this);
    address trader = address(0xBEEF);
    address oracleSource = address(0xFEED);

    bytes32 constant BTC_PERP = keccak256("BTC-PERP");

    function setUp() public {
        usdc = new MockUSDC();
        rfq = new RFQAggregator(owner);
        pro = new VariationalPro(address(usdc), address(rfq), owner);

        pro.addMarket(BTC_PERP, "BTC-PERP", 50, 12);

        rfq.addSource(oracleSource, "Binance");
        rfq.updateMarkPrice(BTC_PERP, 107_420e18);
        rfq.updateQuote(BTC_PERP, oracleSource, 107_420e18);

        usdc.transfer(trader, 100_000e6);
        vm.prank(trader);
        usdc.approve(address(pro), type(uint256).max);
    }

    function test_DepositCollateral() public {
        vm.prank(trader);
        pro.depositCollateral(10_000e6);
        assertEq(pro.availableCollateral(trader), 10_000e6);
    }

    function test_OpenPosition() public {
        vm.startPrank(trader);
        pro.depositCollateral(10_000e6);
        uint256 posId = pro.openPosition(BTC_PERP, true, 50_000e6, 10, 110_000e18);
        vm.stopPrank();
    }

    function test_ClosePosition_Profit() public {
        vm.startPrank(trader);
        pro.depositCollateral(10_000e6);
        uint256 posId = pro.openPosition(BTC_PERP, true, 50_000e6, 10, 110_000e18);
        vm.stopPrank();

        vm.prank(trader);
        int256 pnl = pro.closePosition(posId, 100_000e18);

        assertGt(pnl, 0);
    }

    function test_Liquidation() public {
        vm.startPrank(trader);
        pro.depositCollateral(10_000e6);
        uint256 posId = pro.openPosition(BTC_PERP, true, 50_000e6, 50, 110_000e18);
        vm.stopPrank();

        rfq.updateMarkPrice(BTC_PERP, 95_000e18);

        address liquidator = address(0xCAFE);
        vm.prank(liquidator);
        pro.liquidate(posId);

        IVariationalPro.Position memory pos = pro.getPosition(posId);
        assertFalse(pos.isOpen);
    }

}
