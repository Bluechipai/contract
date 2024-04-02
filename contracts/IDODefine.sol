// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct FundraisinInfo {
    uint256 fundType;
    uint256 quantity;//mul usdt decimals
    uint256 pledgeReward;//require div 10000
}
struct SubsInfo {
    address token;
    address user;
    uint256 quantity;
    uint256 subsTime;
    uint256 from;
    uint256 uintPrice;
    uint256 platPrice;
    uint256 usdt;
}

struct SubsTotalInfo {
    uint256 total;//convert to all usdt
    uint256 settleTime;
}

//transfer out info
struct TransOutInfo {
    address token;
    address user;
    uint256 amount;
    uint256 outTime;
    uint256 state;
}