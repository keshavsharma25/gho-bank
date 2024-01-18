// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Bank} from "../src/Bank.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {MockAToken} from "aave-v3-core/contracts/mocks/upgradeability/MockAToken.sol";

contract BankTest is Test {
    Bank bank;
    IERC20 token;
    IPool pool;

    uint256 constant adminPk = 0x1;
    uint256 constant managerPk = 0x2;
    uint256 constant userPk = 0x3;

    address admin = vm.addr(adminPk);
    address manager = vm.addr(managerPk);
    address user = vm.addr(userPk);

    function setUp() public {
        pool = IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);

        vm.deal(admin, 1 ether);

        vm.prank(admin);
        bank = new Bank(admin, address(pool));
        token = IERC20(0x88541670E55cC00bEEFD87eB59EDd1b7C511AC9a);

        vm.deal(user, 100 ether);

        vm.prank(user);
        // generate AAVE tokens for user
        deal(address(token), user, 1000 * 10 ** 18, true);
    }

    function test_checkTokenBalance() public {
        uint256 balance = token.balanceOf(user);

        assertEq(balance, 1000 ether);
    }

    function test_setManagerRole() public {
        vm.prank(admin);
        bank.assignManagerRole(manager);

        assert(bank.hasRole(bank.MANAGER_ROLE(), manager));
    }

    function test_setAccountConfig() public {
        uint256 _threshold = 75;
        uint256 _interval = 3600;

        vm.prank(user);
        bank.setAccountConfig(_threshold, _interval);

        (uint256 threshold, uint256 interval) = bank.getAccountConfig(user);
        assertEq(threshold, _threshold);
        assertEq(interval, _interval);
    }

    function test_sendSupply() public {
        // before supply
        uint256 amount = 10 * 10 ** 18;

        vm.prank(user);
        token.approve(address(bank), amount);

        vm.prank(admin);
        bank.assignManagerRole(manager);

        assert(bank.hasRole(bank.MANAGER_ROLE(), manager));

        vm.prank(manager);
        bank.supply(address(token), amount, user);

        MockAToken aAaveToken = MockAToken(
            0x6b8558764d3b7572136F17174Cb9aB1DDc7E1259
        );

        uint256 balance = aAaveToken.balanceOf(user);
        assertEq(balance, amount);
    }

    function test_sendSupplyWithPermit() public {
        IERC20Permit permitToken = IERC20Permit(address(token));
        uint256 amount = 10 ether;

        uint256 deadline = block.timestamp + 100;

        bytes32 hash = _getHash(
            user,
            address(bank),
            amount,
            permitToken.nonces(user),
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, hash);

        vm.prank(admin);
        bank.assignManagerRole(manager);

        assert(bank.hasRole(bank.MANAGER_ROLE(), manager));

        vm.prank(manager);
        bank.supplyWithPermit(address(token), amount, user, deadline, v, r, s);

        MockAToken aAaveToken = MockAToken(
            0x6b8558764d3b7572136F17174Cb9aB1DDc7E1259
        );

        uint256 balance = aAaveToken.balanceOf(user);
        assertEq(balance, amount);
    }

    function _getHash(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    _getDomainSeparator(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            owner,
                            spender,
                            value,
                            nonce,
                            deadline
                        )
                    )
                )
            );
    }

    function _getDomainSeparator() private pure returns (bytes32) {
        return
            0x0328d646e301d5d9b65c660db2f8ae23d0fa58b47489c9ee4417f272195bbd19;
    }
}
