// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";

contract Bank {
    struct AccountConfig {
        uint256 threshold;
        uint256 interval;
    }

    mapping(address => AccountConfig) private _accountConfigMap;

    constructor() {}
}
