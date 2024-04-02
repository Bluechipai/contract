// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../IDODefine.sol";

interface ITxSign {
    function permit(uint256 fundType,uint256 quantity,uint256 price,uint256 pledgeReward,
        uint256 deadline,
            uint256 salt,
            uint8 v,
            bytes32 r,
            bytes32 s
        ) external;
    function permitWithdraw(
        address account,
        address usdt,
        uint256 fundraisinNo,
        uint256 deadline,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function permitInviteRewards(
        address account,
        uint256 amount,
        uint256 deadline,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}