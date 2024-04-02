// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Staking is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address private admin;
    address private token;
    uint256 public liveRatio;

    struct DepositRecord {
        address user;
        uint256 sType;
        uint256 amount;
        uint256 dtime;
    }

    struct UserLiveStatistic {
        uint256 total;
        uint256 latestTime;
        uint256 interest;
    }
    uint256 public currRecId;
    //index->live deposit record
    mapping (uint256 => DepositRecord) public dRecords;

    //user->live deposit statistic
    mapping (address => UserLiveStatistic) public liveStatistics;

    //user->indexs
    mapping (address => uint256[]) public uLiveIdxs;

    struct FixedPlan {
        uint256 tLen;
        uint256 ratio;
        bool isValid;
    }
    uint256 public currPlanId;
     //index->fixed plan
    mapping (uint256 => FixedPlan) public plans;

    //planId->user->indexs
    mapping (uint256 => mapping (address => uint256[])) public userIndexs;

    uint256 public sTotal;//total staked
    
    struct WdrawRecord {
        address user;
        uint256 amount;
        uint256 interest;
        uint256 wTime;
        uint256 day;
        uint256 ratio;
    }
    uint256 public currWdrawId;
    //index->withdraw record
    mapping (uint256 => WdrawRecord) public wdrawRecs;
    //withdraw index->deposit index
    mapping (uint256 => uint256[]) private wdRels;

    uint256 public lTotal;
    //plan id->total
    mapping (uint256 => uint256) public fTotals;

    function initialize(address _admin, uint256 _liveRatio) public virtual initializer {
        __Ownable_init();
        admin = _admin;
        liveRatio = _liveRatio;
    }

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Illegal operation");
        _;
    }

    function setAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    function setToken(address _token) public onlyAdmin {
        token = _token;
    }

    function setLiveRatio(uint256 _liveRatio) public onlyAdmin {
        liveRatio = _liveRatio;
    }

    function addPlan(uint256[] memory _days, uint256[] memory _ratios) public onlyAdmin {
        require(_days.length>0&&_ratios.length>0, "Paramter is error");
        for(uint256 i = 0;i < _days.length; i++) {
            plans[currPlanId] = FixedPlan({
                tLen: _days[i],
                ratio: _ratios[i],
                isValid: true
            });
            currPlanId = currPlanId.add(1);
        }
    }

    function editPlan(uint256 _idx, uint256 _day, uint256 _ratio) public onlyAdmin {
        require(_day>0&&_ratio>0, "Must be greater than 0");
        plans[_idx].tLen = _day;
        plans[_idx].ratio = _ratio;
    }

    function setPlanState(uint256 _idx, bool _isValid) public onlyAdmin {
        require(plans[_idx].isValid!=_isValid,"No update required");
        plans[_idx].isValid = _isValid;
    }
    
    function fixedDeposit(uint256 _planId, uint256 _amt) public {
        require(_amt>0,"The amount must be greater than 0");
        require(userIndexs[_planId][msg.sender].length<=20,"Please withdraw and then pledge again");

        userIndexs[_planId][msg.sender].push(currRecId);
        dRecords[currRecId] = DepositRecord({
            user: msg.sender,
            sType: 2,
            amount: _amt,
            dtime: block.timestamp
        });
        currRecId = currRecId.add(1);
        sTotal = _amt.add(sTotal);
        fTotals[_planId] = _amt.add(fTotals[_planId]);
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amt);
    }
    
    function calFixed(address _user, uint256 _planId) public view returns (uint256, uint256) {
        uint256[] memory idxs = userIndexs[_planId][_user];
        uint256 total = 0;
        uint256 interestTotal = 0;
        for(uint256 i =0;i < idxs.length;i++) {
            uint256 timeLen = plans[_planId].tLen.mul(86400);
            uint256 time = dRecords[idxs[i]].dtime.add(timeLen);
            
            if(block.timestamp>=time) {
                uint256 interest = dRecords[idxs[i]].amount.mul(timeLen).mul(plans[_planId].ratio).div(10000).div(31536000);
                interestTotal = interestTotal.add(interest);
            }
            total = total.add(dRecords[idxs[i]].amount);
        }
        return (total, interestTotal);
    }
    
    function fixedWithdraw(uint256 _planId) public {
        uint256[] memory ids = userIndexs[_planId][msg.sender];
        require(ids.length>0,"You haven't pledged anything");
        (uint256 total, uint256 interestTotal) = calFixed(msg.sender, _planId);
        require(total>0,"The withdrawable amount is 0");
        sTotal = sTotal.sub(total);
        fTotals[_planId] = fTotals[_planId].sub(total);

        wdrawRecs[currWdrawId] = WdrawRecord({
            user: msg.sender,
            amount: total,
            interest: interestTotal,
            wTime: block.timestamp,
            day: plans[_planId].tLen,
            ratio: plans[_planId].ratio
        });
        wdRels[currWdrawId] = ids;
        currWdrawId = currWdrawId.add(1);
        
        delete userIndexs[_planId][msg.sender];
        IERC20(token).safeTransfer(msg.sender, total.add(interestTotal));
    }

    function calLiveInterest(uint256 total, uint256 latestTime) public view returns (uint256) {
        uint256 minusSec = block.timestamp-latestTime;
        uint256 interest = total.mul(minusSec).mul(liveRatio).div(10000).div(31536000);
        return interest;
    }

    function liveDeposit(uint256 _amt) public {
        require(_amt>0,"The amount must be greater than 0");
        require(uLiveIdxs[msg.sender].length<=20,"Please withdraw and then pledge again");

        UserLiveStatistic storage info = liveStatistics[msg.sender];
        if(info.total>0) {
            uint256 interest = calLiveInterest(info.total, info.latestTime);
            info.interest = interest.add(info.interest);
        }
        info.total = _amt.add(info.total);
        info.latestTime = block.timestamp;
        uLiveIdxs[msg.sender].push(currRecId);
        dRecords[currRecId] = DepositRecord({
            user: msg.sender,
            sType: 1,
            amount: _amt,
            dtime: block.timestamp
        });
        currRecId = currRecId.add(1);
        sTotal = _amt.add(sTotal);
        lTotal = _amt.add(lTotal);
        //IERC20(token).safeTransfer(to, amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amt);
    }

    function liveWithdraw() public {
        UserLiveStatistic storage info = liveStatistics[msg.sender];
        require(info.total>0,"The withdrawable amount is 0");
        
        uint256 interest = calLiveInterest(info.total, info.latestTime);
        info.interest = interest.add(info.interest);
        sTotal = sTotal.sub(info.total);
        lTotal = lTotal.sub(info.total);
        uint256 amount = info.total.add(info.interest);

        wdrawRecs[currWdrawId] = WdrawRecord({
            user: msg.sender,
            amount: info.total,
            interest: info.interest,
            wTime: block.timestamp,
            day: 0,
            ratio: liveRatio
        });
        wdRels[currWdrawId] = uLiveIdxs[msg.sender];
        currWdrawId = currWdrawId.add(1);

        info.total = 0;
        info.interest = 0;
        info.latestTime = 0;
        delete uLiveIdxs[msg.sender];

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function withdraw(uint256 _amt) public onlyAdmin {
        uint256 bal = IERC20(token).balanceOf(address(this));
        require((bal-sTotal)>=_amt,"No enough balance");
        IERC20(token).safeTransfer(msg.sender, _amt);
    }

    function getFixedTotal(address _user) public view returns (uint256, uint256) {
        uint256 total = 0;
        uint256 interestTotal = 0;
        for(uint256 i = 0;i < currPlanId;i++) {
            (uint256 subT, uint256 subI) = calFixed(_user, i);
            total = total.add(subT);
            interestTotal = interestTotal.add(subI);
        }
        return (total, interestTotal);
    }

    function getLiveTotal(address _user) public view returns (uint256, uint256) {
        uint256 interestTotal = 0;
        UserLiveStatistic memory info = liveStatistics[_user];
        if(info.total>0) {
            uint256 interest = calLiveInterest(info.total, info.latestTime);
            interestTotal = interest.add(info.interest);
        }
        return (info.total, interestTotal);
    }

    function getWdRels(uint256 _wdrawId) public view returns (uint256[] memory) {
        return wdRels[_wdrawId];
    }

    receive() external payable {}

    uint256[49] private __gap;
}