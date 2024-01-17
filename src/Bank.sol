// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract Bank is AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    event SuppliedToAavePool(
        address indexed account,
        address indexed asset,
        uint256 amount
    );

    event AccountConfigured(
        address indexed account,
        uint256 threshold,
        uint256 interval
    );

    struct AccountConfig {
        uint256 threshold;
        uint256 interval;
    }

    IPool immutable AaveV3Pool;

    mapping(address => AccountConfig) private _accountConfigMap;

    constructor(address _owner, address aaveV3PoolAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        AaveV3Pool = IPool(aaveV3PoolAddress);
    }

    receive() external payable {}

    fallback() external payable {}

    function setAccountConfig(uint256 _threshold, uint256 _interval) public {
        _accountConfigMap[msg.sender] = AccountConfig(_threshold, _interval);
    }

    function supply(
        address _asset,
        uint256 _amount,
        address _account
    ) public onlyRole(MANAGER_ROLE) {
        // create an IERC20 for the asset
        IERC20 asset = IERC20(_asset);

        //check for allowance
        uint256 allowance = asset.allowance(_account, address(this));
        require(allowance <= _amount, "Not enough allowance");

        // transfer the asset to the Bank (this contract)
        asset.transferFrom(_account, address(this), _amount);

        // approve the pool to spend the asset
        asset.approve(address(AaveV3Pool), _amount);

        // supply the asset to the pool (deposit) and use _account as onBehalfOf
        AaveV3Pool.supply(_asset, _amount, _account, 0);
    }

    function supplyWithPermit(
        address _asset,
        uint256 _amount,
        address _account,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyRole(MANAGER_ROLE) {
        // create an IERC20 for the asset
        IERC20Permit permitAsset = IERC20Permit(_asset);
        IERC20 asset = IERC20(_asset);

        // approve the bank to supply the asset
        permitAsset.permit(_account, address(this), _amount, deadline, v, r, s);

        //check for allowance
        uint256 allowance = asset.allowance(_account, address(this));
        require(allowance <= _amount, "Not enough allowance");

        // transfer the asset to the Bank (this contract)
        asset.transferFrom(_account, address(this), _amount);

        // approve the pool to spend the asset
        asset.approve(address(AaveV3Pool), _amount);

        // supply the asset to the pool (deposit) and use _account as onBehalfOf
        AaveV3Pool.supply(_asset, _amount, _account, 0);
    }

    function assignManagerRole(
        address _manager
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MANAGER_ROLE, _manager);
    }

    function revokeManagerRole(
        address _manager
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MANAGER_ROLE, _manager);
    }

    function getAccountConfig(
        address _account
    ) public view returns (uint256, uint256) {
        return (
            _accountConfigMap[_account].threshold,
            _accountConfigMap[_account].interval
        );
    }
}
