// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IEIP20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/ISetting.sol";
import "./interfaces/ITxSign.sol";
import "./IDODefine.sol";

contract IDO is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address private settAddr;

    //index->fundraisinNo
    mapping(uint256 => uint256) public fundNos;
    //fundraisinNo->fundraisin info
    mapping(uint256 => FundraisinInfo) public fundRecords;
    //fundraisinNo->state
    mapping(uint256 => uint256) public states;
    //fundraisinNo->riskLevel
    mapping(uint256 => uint256) public riskLevels;
    //fundraisinNo->subscribe token
    mapping(uint256 => address) public subsTokens;
    //fundraisinNo->min amount
    mapping(uint256 => uint256) public minAmounts;
    //fundraisinNo->max amount
    mapping(uint256 => uint256) public maxAmounts;
    //fundraisinNo->price mul usdt decimals
    mapping(uint256 => uint256) public prices;

    uint256 public currFundId;

    //fundraisinNo->current index
    mapping(uint256 => uint256) public subsCurrIndexs;

    //fundraisinNo->index->info
    mapping(uint256 => mapping(uint256 => SubsInfo)) public subsRecords;

    //fundraisinNo->index->state
    mapping(uint256 => mapping(uint256 => uint256)) public subsStates;

    //fundraisinNo->user->indexs
    mapping(uint256 => mapping(address => uint256[])) public userSubsIndexs;

    //fundraisinNo->user->SubsTotalInfo
    mapping(uint256 => mapping(address => SubsTotalInfo)) public utsInfos;
    //user->amt-usdt
    mapping(address => uint256) public lvAmts;

    //fundraisinNo->user->token->amt
    mapping(uint256 => mapping(address => mapping(address => uint256))) public userSubsAmts;

    //fundraisinNo->amount convert all to usdt
    mapping(uint256 => uint256) public fundAmounts;
    //fundraisinNo->bool
    mapping(uint256 => bool) public notFirstWdraw;
    //fundraisinNo->token->amount
    mapping(uint256 =>  mapping(address => uint256)) public leaveAmts;

    //fundraisinNo->token->amount
    mapping(uint256 =>  mapping(address => uint256)) public hasFundsAmounts;

    //claim info
    //fundraisinNo->user->token->amount
    mapping(uint256 => mapping(address => mapping(address => uint256))) public pledgeRewards;

    //fundraisinNo->user->amount
    mapping(uint256 => mapping(address => uint256)) public userRewardsHasPaid;

    //fundraisinNo->end time 
    mapping(uint256 => uint256) public endTimes;

    //fundraisinNo->user->amount
    mapping(uint256 => mapping(address => uint256)) public claimSubsRecords;

    //fundraisinNo->current index-transfer out
    mapping(uint256 => uint256) public outCurrIndexs;

    //fundraisinNo->index->info
    mapping(uint256 => mapping(uint256 => TransOutInfo)) public outRecords;

    //fundraisinNo->user->indexs -transfer out
    mapping(uint256 => mapping(address => uint256[])) public outIndexs;

    //fundraisinNo->user->token->bool(in transfering) 1:
    mapping(uint256 => mapping(address => mapping(address => bool))) public tOutStates;

    //user->amount
    mapping(address => uint256) public totalInviteRewards;

    address private authorizer;
    address private signAddr;
    address private admin;
    address private platToken;
    uint256 public accTotal;

    function initialize(
        address _admin,
        address _platToken,
        address _authorizer,
        address _signAddr,
        address _settAddr
    ) public virtual initializer {
        __Ownable_init();
        authorizer = _authorizer;
        signAddr = _signAddr;
        admin = _admin;
        platToken = _platToken;
        settAddr = _settAddr;
    }

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Illegal operation");
        _;
    }

    function setAuthorizer(address _authorizer) public onlyAdmin {
        authorizer = _authorizer;
    }

    function setSignAddr(address _signAddr) public onlyAdmin {
        signAddr = _signAddr;
    }

    function setAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    function setSettAddr(address _settAddr) public onlyAdmin {
        settAddr = _settAddr;
    }

    function setPlatToken(address _paltToken) public onlyAdmin {
        platToken = _paltToken;
    }

    function setIdoPrice(uint256 fundraisinNo, uint256 _idoPrice) public onlyAdmin {
        prices[fundraisinNo] = _idoPrice;
    }

    function usdtAddr() public view returns (address) {
       return ISetting(settAddr).usdtAddr();
    }

    function feeAddr() public view returns (address) {
       return ISetting(settAddr).feeAddr();
    }

    function fee(uint256 fundraisinNo) public view returns (uint256) {
        return ISetting(settAddr).fee(fundRecords[fundraisinNo].fundType);
    }

    function setStateAndRiskLevel(uint256 fundraisinNo, uint256 state, uint256 riskLevel, bool isZkSync, address _subsToken) public onlyAdmin {
        require(states[fundraisinNo]!=4,"Financing is has completed");
        if (riskLevels[fundraisinNo]!=riskLevel) {
            riskLevels[fundraisinNo] = riskLevel;
            if (riskLevel==3) {
                if (states[fundraisinNo]==4) {
                    states[fundraisinNo] = 5;
                } else {
                    states[fundraisinNo] = 3;
                }
                endTimes[fundraisinNo] = block.timestamp;
            }
        }
        if (states[fundraisinNo]!=state) {
            if (state==4&&isZkSync) {
                require(_subsToken != address(0), "Invalid subscribe token");
                subsTokens[fundraisinNo] = _subsToken;
            }
            states[fundraisinNo] = state;
            if (state==3||state==4||state==5) {
                endTimes[fundraisinNo] = block.timestamp;
            } else {
                endTimes[fundraisinNo] = 0;
            }
        }
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
    }

    function _transfer(address token, address to, uint256 amount) internal {
        if (token != address(0)){
            IERC20(token).safeTransfer(to, amount);
        } else {//ETH
            safeTransferETH(to, amount);
        }
    }
    
    function fundraisin(uint256 fundraisinNo, uint256 fundType,
    uint256 quantity, uint256 price, 
    uint256 pledgeReward,
    uint256 minAmount, uint256 maxAmount, 
    uint256 deadline, uint256 salt,
    uint8 v, bytes32 r, bytes32 s) public onlyAdmin {
        require(states[fundraisinNo]==0,"The fundraising has been released");
        
        ITxSign(signAddr).permit(fundType, quantity, price, pledgeReward, deadline, salt, v, r, s);

        fundRecords[fundraisinNo] = FundraisinInfo({
            fundType: fundType,
            quantity: quantity,
            pledgeReward: pledgeReward
        });
        prices[fundraisinNo] = price;
        minAmounts[fundraisinNo] = minAmount;
        maxAmounts[fundraisinNo] = maxAmount;
        states[fundraisinNo] = 1;
        fundNos[currFundId] = fundraisinNo;
        currFundId = currFundId+1;
    }

    function subscribe(uint256 fundraisinNo, address _token, uint256 _amt) public payable {
        require(ISetting(settAddr).ok(_token),"Token address not allowed");
        require(!tOutStates[fundraisinNo][msg.sender][_token],"Transfer out in progress");
        require(states[fundraisinNo]==1,"The fundraising has not been released");
        if (_token==address(0)) {
            _amt = msg.value;
        }
        
        (uint256 unitPrice, uint8 dec) = ISetting(settAddr).getPrice(_token);
        uint256 platPrice = 0;
        if(_token==platToken) {
            platPrice = unitPrice;
        } else {
            (platPrice,) = ISetting(settAddr).getPrice(platToken);
        }
        uint256 hasSAmt = utsInfos[fundraisinNo][msg.sender].total;
        
        uint256 lvFee = ISetting(settAddr).lv(_token,fundRecords[fundraisinNo].fundType,lvAmts[msg.sender]);
        lvFee = _amt.mul(lvFee).div(10000);
        uint256 rlAmt = _amt.sub(lvFee);

        uint256 usdtAmount = rlAmt.mul(unitPrice).div(10**uint256(dec));
        uint256 total = usdtAmount.add(fundAmounts[fundraisinNo]);
        require(total<=fundRecords[fundraisinNo].quantity,"Exceeding the fundraising amount");
        
        require((hasSAmt+usdtAmount)>=minAmounts[fundraisinNo],"Cannot be less than the minimum limit");
        require((hasSAmt+usdtAmount)<=maxAmounts[fundraisinNo],"Exceeding subscription limit");
        
        uint256 index = subsCurrIndexs[fundraisinNo];
        subsRecords[fundraisinNo][index] = SubsInfo({
            token: _token,
            user: msg.sender,
            quantity: rlAmt,
            subsTime: block.timestamp,
            from: 0,
            uintPrice: unitPrice,
            platPrice: platPrice,
            usdt: usdtAmount
        });
        userSubsIndexs[fundraisinNo][msg.sender].push(index);
        subsCurrIndexs[fundraisinNo] = index+1;
        fundAmounts[fundraisinNo] = total;
        
        hasFundsAmounts[fundraisinNo][_token] = rlAmt.add(hasFundsAmounts[fundraisinNo][_token]);

        confirm(fundraisinNo, msg.sender, usdtAmount, rlAmt, _token);

        if (_token != address(0)){
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amt);
        }
        _transfer(_token, feeAddr(), lvFee);
    }

    function transferOut(uint256 fundraisinNo, address _token) public {
        require(!tOutStates[fundraisinNo][msg.sender][_token],"Transfer out in progress");
        require(states[fundraisinNo]!=3&&states[fundraisinNo]!=5,"The fundraising has been stop");

        tOutStates[fundraisinNo][msg.sender][_token] = true;
        uint256 outAmount = 0;
        if(_token==usdtAddr()) {
            outAmount = userSubsAmts[fundraisinNo][msg.sender][usdtAddr()];
        } else {
            outAmount = userSubsAmts[fundraisinNo][msg.sender][_token];
        }
        uint256 index = outCurrIndexs[fundraisinNo];
        outRecords[fundraisinNo][index] = TransOutInfo({
            token: _token,
            user: msg.sender,
            amount: outAmount,
            outTime: block.timestamp,
            state: 2
        });
        outIndexs[fundraisinNo][msg.sender].push(index);
        outCurrIndexs[fundraisinNo] = index+1;
    }

    function cancelTransferOut(uint256 fundraisinNo, address _token) public {
        require(tOutStates[fundraisinNo][msg.sender][_token], "Transfer out not in progress");
        tOutStates[fundraisinNo][msg.sender][_token] = false;
        uint256[] memory ids = outIndexs[fundraisinNo][msg.sender];
        for (uint256 i =0;i < ids.length;i++) {
            if(_token==outRecords[fundraisinNo][ids[i]].token) {
                outRecords[fundraisinNo][ids[i]].state = 3;
            }
        }
    }

    function receiveTransferOut(uint256 fundraisinNo, uint256 amount, address from, uint256 fromIndex) public payable {
        require(msg.sender!=from,"You can't buy your own");
        require(states[fundraisinNo]!=3&&states[fundraisinNo]!=5,"Unable to take over the resale order");
        require(utsInfos[fundraisinNo][msg.sender].total==0,"You have subscribed");

        TransOutInfo storage outInfo = outRecords[fundraisinNo][fromIndex];
        require(outInfo.amount==amount,"Incorrect subscription amount");
        require(tOutStates[fundraisinNo][from][outInfo.token],"Transfer out not in progress");
        
        uint256[] memory ids = userSubsIndexs[fundraisinNo][from];
        uint256 hasSubsAmount = 0;
        for (uint256 i =0;i < ids.length;i++) {
            if (subsStates[fundraisinNo][ids[i]]==0) {//no transfer out
                if(subsRecords[fundraisinNo][ids[i]].token==outInfo.token) {
                    hasSubsAmount += subsRecords[fundraisinNo][ids[i]].quantity;
                    subsStates[fundraisinNo][ids[i]] = 2;
                }
            }
        }

        if (outInfo.token==address(0)) {
            amount = msg.value;
        }
        require(amount==hasSubsAmount,"Incorrect subscription amount");

        tOutStates[fundraisinNo][from][outInfo.token] = false;
        outInfo.state = 1;

        uint256 usdtAmount = 0;
        SubsTotalInfo storage totalInfo = utsInfos[fundraisinNo][from];
        if(outInfo.token==usdtAddr()) {
            userSubsAmts[fundraisinNo][from][usdtAddr()] = userSubsAmts[fundraisinNo][from][usdtAddr()].sub(amount);
            usdtAmount = amount;
        } else {
            usdtAmount = totalInfo.total.sub(userSubsAmts[fundraisinNo][from][usdtAddr()]);
            userSubsAmts[fundraisinNo][from][outInfo.token] = 0;
        }
        totalInfo.total = totalInfo.total.sub(usdtAmount);
        lvAmts[from] = lvAmts[from].sub(usdtAmount);
        if(totalInfo.total==0) {
            totalInfo.settleTime = 0;
        }
        pledgeRewards[fundraisinNo][from][outInfo.token] = 0;

        (uint256 unitPrice, uint8 dec) = ISetting(settAddr).getPrice(outInfo.token);
        uint256 platPrice = 0;
        if(outInfo.token==platToken) {
            platPrice = unitPrice;
        } else {
            (platPrice,) = ISetting(settAddr).getPrice(platToken);
        }
        usdtAmount = amount.mul(unitPrice).div(10**uint256(dec));

        uint256 index = subsCurrIndexs[fundraisinNo];
        subsRecords[fundraisinNo][index] = SubsInfo({
            token: outInfo.token,
            user: msg.sender,
            quantity: amount,
            subsTime: block.timestamp,
            from: fromIndex,
            uintPrice: unitPrice,
            platPrice: platPrice,
            usdt: usdtAmount
        });

        userSubsIndexs[fundraisinNo][msg.sender].push(index);
        subsCurrIndexs[fundraisinNo] = index+1;

        confirm(fundraisinNo, msg.sender, usdtAmount, amount, outInfo.token);

        uint256 outFee = amount.mul(ISetting(settAddr).transOutFee(fundRecords[fundraisinNo].fundType)).div(10000);

        if (outInfo.token != address(0)){
            IERC20(outInfo.token).safeTransferFrom(msg.sender, address(this), amount);
        }
        _transfer(outInfo.token, from, amount.sub(outFee));
        _transfer(outInfo.token, feeAddr(), outFee);
    }

    function redeem(uint256 fundraisinNo, address _token) public {
        require(!tOutStates[fundraisinNo][msg.sender][_token],"Transfer out in progress");
        require(states[fundraisinNo]==1||states[fundraisinNo]==3||states[fundraisinNo]==5,"Cannot be redeemed");
        SubsTotalInfo storage totalInfo = utsInfos[fundraisinNo][msg.sender];
        require(totalInfo.total>0,"You have not subscribed");

        uint256 platAmount = 0;
        if (states[fundraisinNo]!=1) {
            (uint256 rewards,) = getDepositRewards(fundraisinNo, msg.sender, _token);
            platAmount = rewards.add(pledgeRewards[fundraisinNo][msg.sender][_token]);
            require(IERC20(platToken).balanceOf(address(this))>=platAmount,"Not enough balance for claim");
            userRewardsHasPaid[fundraisinNo][msg.sender] = platAmount.add(userRewardsHasPaid[fundraisinNo][msg.sender]);
            // if(fundRecords[fundraisinNo].fundType!=1) {
            //     hasSubsAmount = 0;
            // }
        }

        uint256[] memory ids = userSubsIndexs[fundraisinNo][msg.sender];
        uint256 hasSubsAmount = 0;
        uint256 outFee = 0;
        uint256 pubFee = ISetting(settAddr).publicFee();
        for (uint256 i = 0;i < ids.length;i++) {
            if (subsStates[fundraisinNo][ids[i]]==0&&subsRecords[fundraisinNo][ids[i]].token==_token) {
                hasSubsAmount += subsRecords[fundraisinNo][ids[i]].quantity;
                subsStates[fundraisinNo][ids[i]] = 1;
                if (states[fundraisinNo]==1) {
                    if(fundRecords[fundraisinNo].fundType==1) {
                        outFee = outFee.add(subsRecords[fundraisinNo][ids[i]].quantity.mul(pubFee).div(10000));
                    } else {
                        outFee = outFee.add(ISetting(settAddr).getRedeemFee(subsRecords[fundraisinNo][ids[i]].quantity, subsRecords[fundraisinNo][ids[i]].subsTime));
                    }
                }
            }
        }

        pledgeRewards[fundraisinNo][msg.sender][_token] = 0;

        uint256 usdtAmount = 0;
        if (hasSubsAmount>0) {
            if(_token==usdtAddr()) {
                usdtAmount = hasSubsAmount;
                userSubsAmts[fundraisinNo][msg.sender][usdtAddr()] = userSubsAmts[fundraisinNo][msg.sender][usdtAddr()].sub(usdtAmount);
            } else {
                usdtAmount = totalInfo.total.sub(userSubsAmts[fundraisinNo][msg.sender][usdtAddr()]);
                userSubsAmts[fundraisinNo][msg.sender][_token] = 0;
            }
            totalInfo.total = totalInfo.total.sub(usdtAmount);
            lvAmts[msg.sender] = lvAmts[msg.sender].sub(usdtAmount);
            if(totalInfo.total==0) {
                totalInfo.settleTime = 0;
            }
            fundAmounts[fundraisinNo] = fundAmounts[fundraisinNo].sub(usdtAmount);
            hasFundsAmounts[fundraisinNo][_token] = hasFundsAmounts[fundraisinNo][_token].sub(hasSubsAmount);

            _transfer(_token, msg.sender, hasSubsAmount.sub(outFee));
        }
        
        if (outFee>0) {
            _transfer(_token, feeAddr(), outFee);
        }
        if(platAmount>0) {
            IERC20(platToken).safeTransfer(msg.sender, platAmount);
        }
    }

    function claim(uint256 fundraisinNo) public {
        require(prices[fundraisinNo]>0,"Please set IDO price");
        require(claimSubsRecords[fundraisinNo][msg.sender] == 0,"Has been claimed");
        require(states[fundraisinNo]==4,"Financing is not completed");
        address oToken = subsTokens[fundraisinNo];//xxx token
        require(oToken != address(0),"The withdrawable amount is 0");

        uint256 subsAmount = utsInfos[fundraisinNo][msg.sender].total;//usdt amount
        subsAmount = subsAmount.mul(10**uint256(IEIP20(oToken).decimals())).div(prices[fundraisinNo]);
        require(IERC20(oToken).balanceOf(address(this))>=subsAmount,"Not enough subscribe token balance for claim");
        
        uint256 subsFee = subsAmount.mul(fee(fundraisinNo)).div(10000);
        claimSubsRecords[fundraisinNo][msg.sender] = subsAmount;
        
        IERC20(oToken).safeTransfer(msg.sender, subsAmount.sub(subsFee));
        IERC20(oToken).safeTransfer(feeAddr(), subsFee);
    }

    function withdraw(uint256 fundraisinNo, uint256 deadline, uint256 salt,
    uint8 v, bytes32 r, bytes32 s) public {
        if(fundRecords[fundraisinNo].fundType==1||(fundRecords[fundraisinNo].fundType==2&&states[fundraisinNo]!=3&&states[fundraisinNo]!=5)) {
            require(states[fundraisinNo]==4,"Financing is not completed and rewards cannot be withdrawn");
        }
        ITxSign(signAddr).permitWithdraw(msg.sender, usdtAddr(), fundraisinNo, deadline, salt, v, r, s);

        address[] memory tks = ISetting(settAddr).getTokens();
        if(!notFirstWdraw[fundraisinNo]) {
            notFirstWdraw[fundraisinNo] = true;
            for(uint i =0 ;i<tks.length;i++) {
                leaveAmts[fundraisinNo][tks[i]] = hasFundsAmounts[fundraisinNo][tks[i]];
            }
        }
        bool isOk = false;
        for(uint i =0 ;i<tks.length;i++) {
            if(leaveAmts[fundraisinNo][tks[i]]>0) {
                isOk = true;
            }
        }
        require(isOk,"The withdrawable amount is 0");

        for(uint i =0 ;i<tks.length;i++) {
            uint256 amountIn = leaveAmts[fundraisinNo][tks[i]];
            if(amountIn>0){
                uint256 realAmt = 0;
                if(tks[i]==usdtAddr()) {
                    realAmt = amountIn;
                    _transfer(usdtAddr(), msg.sender, amountIn);
                } else {
                    address[] memory paths;
                    paths = new address[](2);
                    paths[0] = tks[i];
                    paths[1] = usdtAddr();
                    uint256[] memory amountsExpected = IUniswapV2Router02(ISetting(settAddr).routerAddr()).getAmountsOut(amountIn, paths);
                    realAmt = amountsExpected[0];
                    address routerAddr = ISetting(settAddr).routerAddr();
                    IERC20(tks[i]).approve(routerAddr,realAmt);

                    IUniswapV2Router02(routerAddr).swapExactTokensForTokens(
                        amountsExpected[0],
                        (amountsExpected[1]*990)/1000,
                        paths,
                        msg.sender,
                        deadline);
                }
                leaveAmts[fundraisinNo][tks[i]] = leaveAmts[fundraisinNo][tks[i]].sub(realAmt);
            }
        }
    }

    function withdrawInviteRewards(uint256 amount, uint256 deadline, uint256 salt,
    uint8 v, bytes32 r, bytes32 s) public {
        require(IERC20(platToken).balanceOf(address(this))>=amount,"Not enough platform token balance");
        
        ITxSign(signAddr).permitInviteRewards(msg.sender, amount, deadline, salt, v, r, s);
        totalInviteRewards[msg.sender] = amount.add(totalInviteRewards[msg.sender]);
        _transfer(platToken, msg.sender, amount);
    }

    function confirm(uint256 fundraisinNo, address user, uint256 usdtAmount, uint256 chipAmount, address _token) internal {
        (uint256 rewards, uint256 settleTime) = getDepositRewards(fundraisinNo, user, _token);
        if (rewards>0) {
            pledgeRewards[fundraisinNo][user][_token] = rewards.add(pledgeRewards[fundraisinNo][user][_token]);
        }
        SubsTotalInfo storage totalInfo = utsInfos[fundraisinNo][user];
        if(_token==usdtAddr()) {
            userSubsAmts[fundraisinNo][user][usdtAddr()] = usdtAmount.add(userSubsAmts[fundraisinNo][user][usdtAddr()]);
        } else {
            userSubsAmts[fundraisinNo][user][_token] = chipAmount.add(userSubsAmts[fundraisinNo][user][_token]);
        }
        totalInfo.total = usdtAmount.add(totalInfo.total);
        lvAmts[user] = usdtAmount.add(lvAmts[user]);
        accTotal = usdtAmount.add(accTotal);
        totalInfo.settleTime = settleTime;
    }

    function getAllRedeemFee(uint256 fundraisinNo, address user, address token) public view returns (uint256) {
        uint256[] memory ids = userSubsIndexs[fundraisinNo][user];
        uint256 outFee = 0;
        uint256 pubFee = ISetting(settAddr).publicFee();
        for (uint256 i = 0;i < ids.length;i++) {
            if(subsStates[fundraisinNo][ids[i]]==0&&subsRecords[fundraisinNo][ids[i]].token==token) {
                if(fundRecords[fundraisinNo].fundType==1) {
                    outFee = outFee.add(subsRecords[fundraisinNo][ids[i]].quantity.mul(pubFee).div(10000));
                } else {
                    outFee = outFee.add(ISetting(settAddr).getRedeemFee(subsRecords[fundraisinNo][ids[i]].quantity, subsRecords[fundraisinNo][ids[i]].subsTime));
                }
            }
        }
        return outFee;
    }

    function getDepositRewards(uint256 fundraisinNo, address user, address _token) public view returns (uint256, uint256) {
        uint256 settleTime = 0;
        if (endTimes[fundraisinNo]>0) {
            settleTime = endTimes[fundraisinNo];
        } else {
            settleTime = block.timestamp;
        }
        if (utsInfos[fundraisinNo][user].settleTime==0) {
            return (0, settleTime);
        }
        uint256 timeLen = settleTime-utsInfos[fundraisinNo][user].settleTime;
        uint256[] memory ids = userSubsIndexs[fundraisinNo][user];
        uint256 total = 0;
        uint256 one = 10**uint256(IEIP20(platToken).decimals());
        for (uint256 i = 0;i < ids.length;i++) {
            SubsInfo memory info = subsRecords[fundraisinNo][ids[i]];
            if(subsStates[fundraisinNo][ids[i]]==0&&info.token==_token) {
                uint256 platAmount = info.usdt.mul(one).div(info.platPrice);//get plat token amount
                total = total.add(platAmount.mul(fundRecords[fundraisinNo].pledgeReward).div(365).div(86400).mul(timeLen).div(1e4));
            }
        }
        if (total>0) {
            return (total, settleTime);
        }
        return (0, block.timestamp);
    }

    function getSubsInfo(uint256 fundraisinNo,uint256 index) public view returns (SubsInfo memory, uint256) {
        return (subsRecords[fundraisinNo][index], subsStates[fundraisinNo][index]);
    }

    receive() external payable {}

    uint256[49] private __gap;
}