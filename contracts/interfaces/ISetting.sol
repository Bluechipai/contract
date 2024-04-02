// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISetting {
    function ok(address _token) external view returns (bool);
    function getTokens() external view returns (address[] memory);
    function lv(address _token, uint256 _fundType, uint256 _amount) external view returns (uint256);
    function getPrice(address _tokenIn) external view returns (uint256, uint8);
    function publicFee() external view returns (uint256);
    function fee(uint256) external view returns (uint256);
    function transOutFee(uint256 _fundType) external view returns (uint256);
    function getRedeemFee(uint256 amount, uint256 subsTime) external view returns (uint256);
    function usdtAddr() external view returns (address);
    function routerAddr() external view returns (address);
    function wethAddr() external view returns (address);
    function feeAddr() external view returns (address);
}