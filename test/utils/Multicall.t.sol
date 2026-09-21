// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/utils/Multicall.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1000e18);
    }
}

contract MulticallTest is Test {
    

    function test_AggregateBatchesBalanceReads() public {
        Multicall.Call[] memory calls = new Multicall.Call[](2);
        calls[0] = Multicall.Call({
            target: address(token),
            callData: abi.encodeWithSelector(token.balanceOf.selector, alice)
        });
        calls[1] = Multicall.Call({
            target: address(token),
            callData: abi.encodeWithSelector(token.balanceOf.selector, bob)
        });

        (uint256 blockNumber, bytes[] memory results) = multicall.aggregate(calls);

        assertEq(blockNumber, block.number);
        assertEq(abi.decode(results[0], (uint256)), 100e18);
        assertEq(abi.decode(results[1], (uint256)), 50e18);
    }

    function test_AggregateRevertsIfAnyCallFails() public {
        Multicall.Call[] memory calls = new Multicall.Call[](1);
        calls[0] = Multicall.Call({
            target: address(token),
            callData: abi.encodeWithSignature("nonexistentFunction()")
        });

        vm.expectRevert("Multicall: call failed");
        multicall.aggregate(calls);
    }

    function test_TryAggregateReturnsPerCallSuccess() public {
        Multicall.Call[] memory calls = new Multicall.Call[](2);
        calls[0] = Multicall.Call({
            target: address(token),
            callData: abi.encodeWithSelector(token.balanceOf.selector, alice)
        });
        calls[1] = Multicall.Call({
            target: address(token),
            callData: abi.encodeWithSignature("nonexistentFunction()")
        });

        Multicall.Result[] memory results = multicall.tryAggregate(false, calls);

        assertTrue(results[0].success);
        assertEq(abi.decode(results[0].returnData, (uint256)), 100e18);
        assertFalse(results[1].success);
    }

    function test_TryAggregateRevertsWhenRequireSuccessTrue() public {
        Multicall.Call[] memory calls = new Multicall.Call[](1);
        calls[0] = Multicall.Call({
            target: address(token),
            callData: abi.encodeWithSignature("nonexistentFunction()")
        });

        vm.expectRevert("Multicall: call failed");
        multicall.tryAggregate(true, calls);
    }

    function test_GetBlockNumberAndTimestamp() public {
        assertEq(multicall.getBlockNumber(), block.number);
        assertEq(multicall.getCurrentBlockTimestamp(), block.timestamp);
    }
}
