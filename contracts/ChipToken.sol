// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract ChipToken is Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    uint256 public total;
    address private admin;
    uint256 public startTime;
    //uint256 public periodTimeLen = 5 minutes;
    uint256 private periodTimeLen = 30 days;
    //Liquidity Fund
    address private constant lpAddr = 0x64728133b8C6c8bC05F137B484b58E6cE0B3010a;
    //Reward Release
    address private constant rewardAddr = 0xFc442ea231854a6Cf479ad381a02D9DDC8BF7489;
    //Team & Advisors reserve
    address private constant teamAddr = 0xa0D8BC284B97E99d397fc23AB8C3314C873592eD;
    //Marketing
    address private constant marketAddr = 0x438E049CDfdF18991B31C38dd21AFF3da38fa9FD;
    //Seed Sale
    address private constant seedAddr = 0x865e87c926A28F00Be2696a0c52CacE9Ae280B74;
    address private stakingAddr;

    struct FundPool {
        uint256 ratio;
        uint256 periods;
        uint256 lockPeriods;
        uint256 firstRatio;
        uint256 ratioPerPeriod;
    }
    //type->fund pool
    mapping (uint256 => FundPool) private pools;
    //type->periods of unlock
    mapping (uint256 => uint256) public unlockPeriods;
    //type->amount of unlock
    mapping (uint256 => uint256) public unlockAmts;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        address admin_,
        address stakingAddr_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 supply_
        ) public {
        admin = admin_;
        stakingAddr = stakingAddr_;
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        total = supply_;

        _mint(address(this), supply_);
        //Liquidity Fund
        _addPool(1, FundPool({ratio: 2500,periods: 12,lockPeriods: 0,firstRatio: 700,ratioPerPeriod: 150}));
        //Staking Far
        _addPool(2, FundPool({ratio: 4200,periods: 36,lockPeriods: 0,firstRatio: 600,ratioPerPeriod: 100}));
        //Reward Release
        _addPool(3, FundPool({ratio: 1000,periods: 12,lockPeriods: 3,firstRatio: 400,ratioPerPeriod: 50}));
        //Team & Advisors reserve
        _addPool(4, FundPool({ratio: 1200,periods: 24,lockPeriods: 6,firstRatio: 0,ratioPerPeriod: 50}));
        //Marketing
        _addPool(5, FundPool({ratio: 700,periods: 10,lockPeriods: 0,firstRatio: 200,ratioPerPeriod: 50}));
        //Seed Sale
        _addPool(6, FundPool({ratio: 400,periods: 12,lockPeriods: 3,firstRatio: 100,ratioPerPeriod: 25}));
    }

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Illegal operation");
        _;
    }

    function setAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    function _addPool(uint256 _type, FundPool memory pool) internal {
        pools[_type] = pool;
        if(pool.firstRatio>0) {
            uint256 lockAmt = total.mul(pool.firstRatio).div(10000);
            unlockAmts[_type] = lockAmt.add(unlockAmts[_type]);

           _transfer(address(this), getAddr(_type), lockAmt);
        }
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

    function unlock() external onlyAdmin {
        require(startTime>0, "Not set start time of unlcok");

        for(uint256 i =1;i<=6;i++) {
            (uint256 unLockAmt,uint256 periods,uint256 hasUnlockPeriods) = getUnlockInfo(i);
            if(unLockAmt==0) {
                continue;
            }
            unlockAmts[i] = unLockAmt.add(unlockAmts[i]);
            unlockPeriods[i] = periods.add(hasUnlockPeriods);
            _transfer(address(this), getAddr(i), unLockAmt);
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

    function getOmicsInfo(uint256 _type) public view returns (FundPool memory, uint256, uint256, address) {
        (,uint256 periods,uint256 hasUnlockPeriods) = getUnlockInfo(_type);
        address to = getAddr(_type);
        return (pools[_type], hasUnlockPeriods, periods,to);
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function burn(address account, uint256 amount) external onlyAdmin {
        _burn(account, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyAdmin {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }

    receive() external payable {}
}