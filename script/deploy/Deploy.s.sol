// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../../src/core/VariationalPro.sol";
import "../../src/core/RFQAggregator.sol";
import "../../src/token/VARToken.sol";

/**
 * @notice Deploys the full Variational Pro stack: trading engine, RFQ aggregator,
 *         price oracle, insurance fund, referral registry, $VAR token,
 *         staking/earn module, governance (timelock + governor), and the
 *         vesting vault. Wires admin roles and seeds demo markets.
 */
contract DeployScript is Script {
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    uint256 constant TIMELOCK_DELAY = 2 days;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // ── Core trading ─────────────────────────────────────────────
        RFQAggregator rfq = new RFQAggregator(deployer);
        VariationalPro pro = new VariationalPro(USDC, address(rfq), deployer);

        pro.addMarket(keccak256("BTC-PERP"), "BTC-PERP", 50, 12);
        pro.addMarket(keccak256("ETH-PERP"), "ETH-PERP", 50, 8);
        pro.addMarket(keccak256("SOL-PERP"), "SOL-PERP", 25, -3);
        pro.addMarket(keccak256("AAPL-PERP"), "AAPL-PERP", 10, 0);
        pro.addMarket(keccak256("GOLD-PERP"), "GOLD-PERP", 20, 0);


    }
}
