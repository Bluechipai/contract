// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IEIP20.sol";
import "./interfaces/IIdo.sol";
import "./IDODefine.sol";

contract IDOQuery is OwnableUpgradeable {
    using SafeMath for uint256;

    address private admin;
    address private idoAddr;
    address private platAddr;

    address private usdtAddr;
    address private chipAddr;

    struct TokenDecInfo {
        uint8 usdtDecimals;
        uint8 chipDecimals;
        uint8 platDecimals;
    }

    //用户认购信息
    struct UserSubsInfo {
        uint256 userTotalSubs;//用户已认购的总金额USDT
        uint256 userUsdtFunded;//用户已认购的USDT
        uint256 userChipFunded;//用户已认购的chip
        uint256 userPlatAmt;//平台币奖励
    }

    //募资统计信息
    struct FundsInfo {
        bool isStart;//是否已在链上开始募资
        uint256 totalFunded;//项目已募资的总金额USDT
        uint256 usdtFunded;//项目已募资的USDT
        uint256 chipFunded;//项目已募资的chip
        uint256 state;//项目募资状态
        uint256 riskLevel;//项目募资风险
        uint256 idoPrice;//IDO价格
    }

    function initialize(
        address _admin,
        address _idoAddr,
        address _platAddr,
        address _usdtAddr,
        address _chipAddr
    ) public virtual initializer {
        __Ownable_init();
        admin = _admin;
        idoAddr = _idoAddr;
        platAddr = _platAddr;
        usdtAddr = _usdtAddr;
        chipAddr = _chipAddr;
    }

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Illegal operation");
        _;
    }

    function setAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    function setIdoAddr(address _idoAddr) public onlyAdmin {
        idoAddr = _idoAddr;
    }

    function setPlatAddr(address _platAddr) public onlyAdmin {
        platAddr = _platAddr;
    }

    function setUsdtAddr(address _usdtAddr) public onlyAdmin {
        usdtAddr = _usdtAddr;
    }

    function setChipAddr(address _chipAddr) public onlyAdmin {
        chipAddr = _chipAddr;
    }

    function getFundInfo(uint256 fundraisinNo) public view returns (FundsInfo memory) {
        bool isStart = IIdo(idoAddr).fundRecords(fundraisinNo).quantity>0;
        uint256 totalFunded = IIdo(idoAddr).fundAmounts(fundraisinNo);
        uint256 usdtFunded = IIdo(idoAddr).hasFundsAmounts(fundraisinNo, usdtAddr);
        uint256 chipFunded = IIdo(idoAddr).hasFundsAmounts(fundraisinNo, chipAddr);

        uint256 state = states(fundraisinNo);
        uint256 riskLevel = riskLevels(fundraisinNo);
        uint256 idoPrice = prices(fundraisinNo);

        return FundsInfo({
            isStart: isStart,
            totalFunded: totalFunded,
            usdtFunded: usdtFunded,
            chipFunded: chipFunded,
            state: state,
            riskLevel: riskLevel,
            idoPrice: idoPrice
        });
    }

    function getUserFundInfo(uint256 fundraisinNo, address user) public view returns (UserSubsInfo memory) {
        uint256 userTotalSubs = IIdo(idoAddr).utsInfos(fundraisinNo, user).total;
        uint256 userUsdtFunded = IIdo(idoAddr).userSubsAmts(fundraisinNo, user, usdtAddr);
        uint256 userChipFunded = IIdo(idoAddr).userSubsAmts(fundraisinNo, user, chipAddr);
        (uint256 uRewards,uint256 chipRewards) = getPlatRewards(fundraisinNo, user);
        return  UserSubsInfo({
                userTotalSubs: userTotalSubs,
                userUsdtFunded: userUsdtFunded,
                userChipFunded: userChipFunded,
                userPlatAmt: uRewards.add(chipRewards)
            });
    }

    function getTokenDecimals() public view returns (TokenDecInfo memory) {
        uint8 usdtDecimals = IEIP20(usdtAddr).decimals();
        uint8 chipDecimals = IEIP20(chipAddr).decimals();
        uint8 platDecimals = IEIP20(platAddr).decimals();

        return TokenDecInfo({
            usdtDecimals: usdtDecimals,
            chipDecimals: chipDecimals,
            platDecimals: platDecimals
        });
    }

    //用户获得的项目方代币的数量及需要的手续费
    function getUserSubsTokenAmt(uint256 fundraisinNo, address user) public view returns (uint256, uint256){
        uint256 subsAmount = IIdo(idoAddr).utsInfos(fundraisinNo, user).total;
        uint256 subsFee = 0;
        uint price = IIdo(idoAddr).prices(fundraisinNo);
        if (price>0) {
            subsAmount = subsAmount.mul(10**18).div(price);
            subsFee = subsAmount.mul(IIdo(idoAddr).fee(fundraisinNo)).div(10000);
        } else {
            subsAmount = 0;
        }
        //require convert decimal usdt->xxx token  
        return (subsAmount, subsFee);
    }

    function getPlatRewards(uint256 fundraisinNo, address user) public view returns (uint256, uint256){
        (uint256 rewards,) = IIdo(idoAddr).getDepositRewards(fundraisinNo, user, usdtAddr);
        uint256 prevRewards = IIdo(idoAddr).pledgeRewards(fundraisinNo, user, usdtAddr);
        uint256 uRewards = rewards.add(prevRewards);

        (uint256 rewardsChip,) = IIdo(idoAddr).getDepositRewards(fundraisinNo, user, chipAddr);
        uint256 prevRewardsChip = IIdo(idoAddr).pledgeRewards(fundraisinNo, user, chipAddr);
        uint256 chipRewards = rewardsChip.add(prevRewardsChip);

        return (uRewards, chipRewards);
    }

    function states(uint256 fundraisinNo) public view returns (uint256){
        return IIdo(idoAddr).states(fundraisinNo);
    }

    function riskLevels(uint256 fundraisinNo) public view returns (uint256){
        return IIdo(idoAddr).riskLevels(fundraisinNo);
    }

    function prices(uint256 fundraisinNo) public view returns (uint256){
        return IIdo(idoAddr).prices(fundraisinNo);
    }

    function fundAmounts(uint256 fundraisinNo) public view returns (uint256){
        return IIdo(idoAddr).fundAmounts(fundraisinNo);
    }

    function utsInfos(uint256 fundraisinNo, address user) public view returns (SubsTotalInfo memory) {
        return IIdo(idoAddr).utsInfos(fundraisinNo, user);
    }

    function tOutStates(uint256 fundraisinNo, address user) public view returns (bool, bool) {
        bool usdtState = IIdo(idoAddr).tOutStates(fundraisinNo, user, usdtAddr);
        bool chipState = IIdo(idoAddr).tOutStates(fundraisinNo, user, chipAddr);
        return (usdtState, chipState);
    }

    receive() external payable {}

    uint256[49] private __gap;
}