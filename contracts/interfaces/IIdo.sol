// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../IDODefine.sol";

interface IIdo {
    function fundRecords(uint256 fundraisinNo) external view returns (FundraisinInfo memory);
    function fundAmounts(uint256 fundraisinNo) external view returns (uint256);
    function hasFundsAmounts(uint256 fundraisinNo, address token) external view returns (uint256);
    function userSubsAmts(uint256 fundraisinNo, address user, address token) external view returns (uint256);
    function utsInfos(uint256 fundraisinNo, address user) external view returns (SubsTotalInfo memory);
    function getDepositRewards(uint256 fundraisinNo, address user, address _token) external view returns (uint256, uint256);
    function pledgeRewards(uint256 fundraisinNo, address user, address token) external view returns (uint256);
    function prices(uint256 fundraisinNo) external view returns (uint256);
    function fee(uint256 fundraisinNo) external view returns (uint256);
    function states(uint256 fundraisinNo) external view returns (uint256);
    function riskLevels(uint256 fundraisinNo) external view returns (uint256);
    function tOutStates(uint256 fundraisinNo, address user, address _token) external view returns (bool);
}