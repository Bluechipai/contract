// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract FundPool is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address private admin;
    uint256 public startTime;
    uint256 public periodTimeLen;
    address private token;
    uint256 public total;
    bool private isCall;

    //Liquidity Fund
    address private lpAddr;
    //Reward Release
    address private rewardAddr;
    //Team & Advisors reserve
    address private teamAddr;
    //Marketing
    address private marketAddr;
    //Seed Sale
    address private seedAddr;
    //Staking
    address private stakingAddr;

    struct PoolItem {
        uint256 ratio;
        uint256 periods;
        uint256 lockPeriods;
        uint256 firstRatio;
        uint256 ratioPerPeriod;
    }
    //type->fund pool
    mapping (uint256 => PoolItem) private pools;
    //type->periods of unlock
    mapping (uint256 => uint256) public unlockPeriods;
    //type->amount of unlock
    mapping (uint256 => uint256) public unlockAmts;

    function initialize(address _admin, address stakingAddr_) public virtual initializer {
        __Ownable_init();
        admin = _admin;
        stakingAddr = stakingAddr_;
        periodTimeLen = 30 days;
        total = 1000000000;
        total = total.mul(10**uint256(18));
        lpAddr = 0x64728133b8C6c8bC05F137B484b58E6cE0B3010a;
        rewardAddr = 0xFc442ea231854a6Cf479ad381a02D9DDC8BF7489;
        teamAddr = 0xa0D8BC284B97E99d397fc23AB8C3314C873592eD;
        marketAddr = 0x438E049CDfdF18991B31C38dd21AFF3da38fa9FD;
        seedAddr = 0x865e87c926A28F00Be2696a0c52CacE9Ae280B74;
    }

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Illegal operation");
        _;
    }

    function setAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    function setStakingAddr(address _stakingAddr) external onlyAdmin {
        stakingAddr = _stakingAddr;
    }

    function setStartTime(uint256 _startTime) external onlyAdmin {
        startTime = _startTime;
    }

    function setPtimeLen(uint256 _pTimeLen) external onlyAdmin {
        periodTimeLen = _pTimeLen;
    }

    function setToken(address _token) public onlyAdmin {
        token = _token;
    }

    function addPool(uint256 _type, uint256 ratio,uint256 periods,uint256 lockPeriods,uint256 firstRatio,uint256 ratioPerPeriod) public onlyAdmin {
        pools[_type] = PoolItem({ratio: ratio,periods: periods,lockPeriods: lockPeriods,firstRatio: firstRatio,ratioPerPeriod: ratioPerPeriod});
        if(firstRatio>0) {
            uint256 lockAmt = total.mul(firstRatio).div(10000);
            unlockAmts[_type] = lockAmt.add(unlockAmts[_type]);

            IERC20(token).safeTransfer(getAddr(_type), lockAmt);
        }
    }

    function unlock() external onlyAdmin {
        require(startTime>0, "Not set start time of unlcok");

        for(uint256 i =1;i<=6;i++) {
            (uint256 unLockAmt,uint256 periods,uint256 hasUnlockPeriods) = getUnlockInfo(i);
            if(unLockAmt==0) {
                continue;
            }
            unlockAmts[i] = unLockAmt.add(unlockAmts[i]);
            unlockPeriods[i] = periods.add(hasUnlockPeriods);
            IERC20(token).safeTransfer(getAddr(i), unLockAmt);
        }
    }

    //returns (currentUnlockAmt,unlockPeriods,hasUnlockPeriods)
    function getUnlockInfo(uint256 _type) public view returns (uint256,uint256,uint256) {
        uint256 sTime = startTime.add(pools[_type].lockPeriods.mul(periodTimeLen));
        uint256 hasUnlockPeriods = unlockPeriods[_type];
        if(block.timestamp<=sTime) {
            return (0,0,hasUnlockPeriods);
        }
        uint256 lastCalTime = sTime.add(hasUnlockPeriods.mul(periodTimeLen));
        if(block.timestamp>lastCalTime) {
            uint256 minusSecs = block.timestamp.sub(lastCalTime);
            uint256 periods = minusSecs.div(periodTimeLen);
            uint256 totalPeriods = periods.add(hasUnlockPeriods);
            if(periods>0) {
                if(totalPeriods>pools[_type].periods) {
                    periods = pools[_type].periods.sub(hasUnlockPeriods);
                }
                uint256 unLockAmt = total.mul(periods).mul(pools[_type].ratioPerPeriod).div(10000);
                return (unLockAmt,periods,hasUnlockPeriods);
            }
        }
        return (0,0,hasUnlockPeriods);
    }

    function getOmicsInfo(uint256 _type) public view returns (PoolItem memory, uint256, uint256, address) {
        (,uint256 periods,uint256 hasUnlockPeriods) = getUnlockInfo(_type);
        address to = getAddr(_type);
        return (pools[_type], hasUnlockPeriods, periods,to);
    }

    function getAddr(uint256 _type) public view returns (address) {
        if(_type==1) {
            return lpAddr;
        } else if(_type==2) {
            return stakingAddr;
        } else if(_type==3) {
            return rewardAddr;
        } else if(_type==4) {
            return teamAddr;
        } else if(_type==5) {
            return marketAddr;
        } else if(_type==6) {
            return seedAddr;
        }
    }

    receive() external payable {}

    uint256[49] private __gap;
}