// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Bank} from "../src/Bank.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockAToken} from "aave-v3-core/contracts/mocks/upgradeability/MockAToken.sol";

contract BankTest is Test {
    Bank bank;
    IERC20 token;
    IPool pool;

    address admin = vm.addr(0x1);
    address manager = vm.addr(0x2);
    address user = vm.addr(0x3);

    function setUp() public {
        pool = IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);

        vm.deal(admin, 1 ether);

        vm.prank(admin);
        bank = new Bank(admin, address(pool));
        token = IERC20(0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357);

        vm.deal(user, 100 ether);

        vm.prank(user);
        // generate DAI tokens for user
        deal(address(token), user, 100 * 10 ** 18, true);
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

    function test_checkTokenBalance() public {
        uint256 balance = token.balanceOf(user);

        assertEq(balance, 100 ether);
    }

    function test_supply() public {
        // before supply
        uint256 amount = 100 * 10 ** 18;

        vm.prank(user);
        token.approve(address(bank), amount);

        bank.supply(address(token), amount, user);

        MockAToken aDaiToken = MockAToken(
            0x29598b72eb5CeBd806C5dCD549490FdA35B13cD8
        );

        uint256 balance = aDaiToken.balanceOf(user);
        assertEq(balance, 100 * 10 ** 18);
    }
}
