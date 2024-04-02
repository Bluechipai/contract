// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//募资信息
struct FundraisinInfo {
    uint256 fundType;//1:公 2:私
    uint256 quantity;//mul usdt decimals
    uint256 pledgeReward;//require div 10000
}
//用户认购信息
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

//用户认购汇总信息
struct SubsTotalInfo {
    uint256 total;//convert to all usdt
    uint256 settleTime;//最近一次结算时间
}

//transfer out info
struct TransOutInfo {
    address token;
    address user;
    uint256 amount;
    uint256 outTime;
    uint256 state;//1:已转卖 2:转卖中 3:取消转卖
}