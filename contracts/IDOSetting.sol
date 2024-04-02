// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IEIP20.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract IDOSetting is OwnableUpgradeable {
    using SafeMath for uint256;

    address private admin;
    address[] private tokens;

    address public usdtAddr;
    address public routerAddr;
    address public wethAddr;
    //认购时、赎回时手续费地址
    address public feeAddr;
    
    mapping(address => bool) private validAddrs;
    uint256 public one;

    //公募赎回违约金
    uint256 public publicFee;//must div 10000

    //公募用usdt购买时的固定手费
    uint256 public pubFixed;

    //公募用Chip购买时的手费
    uint256 public lv0;
    uint256 public lv1;
    uint256 public lv2;
    uint256 public lv3;
    uint256 public lv4;
    uint256 public lv5;

    //私募用usdt购买时的固定手费
    uint256 public privFixed;

    //私募用Chip购买时的手费
    uint256 public lv0Priv;
    uint256 public lv1Priv;
    uint256 public lv2Priv;
    uint256 public lv3Priv;
    uint256 public lv4Priv;
    uint256 public lv5Priv;

    uint256 public pubCmsFee;//subscribe token must div 10000
    uint256 public privCmsFee;//subscribe token must div 10000

    uint256 public pubTOutFee;//usdt must div 10000
    uint256 public privTOutFee;//usdt must div 10000

    uint256 public redeemMinFee;//usdt must div 10000
    uint256 public redeemMaxFee;//usdt must div 10000
    uint256 public redeemDay;
    uint256 public redeemReduce;//must div 10000
    
    uint256 public l0Range;
    uint256 public l1Range;
    uint256 public l2Range;
    uint256 public l3Range;
    uint256 public l4Range;

    function initialize(
        address _admin,
        address _routerAddr,
        address _wethAddr,
        address _usdtAddr
    ) public virtual initializer {
        __Ownable_init();
        admin = _admin;
        routerAddr = _routerAddr;
        wethAddr = _wethAddr;
        usdtAddr = _usdtAddr;
        one = 10**uint256(IEIP20(usdtAddr).decimals());
        l0Range = 2000;
        l1Range = 4000;
        l2Range = 20000;
        l3Range = 40000;
        l4Range = 200000;
    }

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Illegal operation");
        _;
    }

    function setAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    function setUsdtAddr(address _usdtAddr) public onlyAdmin {
        usdtAddr = _usdtAddr;
        one = 10**uint256(IEIP20(usdtAddr).decimals());
    }

    function setFeeAddr(address _feeAddr) public onlyAdmin {
        feeAddr = _feeAddr;
    }

    function setRouter(address _routerAddr) public onlyAdmin {
        routerAddr = _routerAddr;
    }

    function setWeth(address _wethAddr) public onlyAdmin {
        wethAddr = _wethAddr;
    }

    function setPubFixed(uint256 _pubFixed) public onlyAdmin {
        pubFixed = _pubFixed;
    }

    function setPrivFixed(uint256 _privFixed) public onlyAdmin {
        privFixed = _privFixed;
    }

    //公募赎回费用
    function setPublicFee(uint256 _publicFee) public onlyAdmin {
        publicFee = _publicFee;
    }

    function addToken(address[] memory _tokens) public onlyAdmin {
        for(uint256 i =0;i < _tokens.length;i++) {
            require(!validAddrs[_tokens[i]], "Address already exists");
            validAddrs[_tokens[i]] = true;
            tokens.push(_tokens[i]);
        }    
    }

    function removeToken(address _token) public onlyAdmin {
        require(validAddrs[_token], "address no exist");
        for(uint i =0;i < tokens.length;i++) {
            if (tokens[i]==_token) {
                tokens[i] = tokens[tokens.length-1];
                tokens.pop();
                validAddrs[_token] = false;
                break;
            }
        }
    }

    function ok(address _token) public view returns (bool) {
        return validAddrs[_token];
    }

    function setLv0(uint256 _lv0) public onlyAdmin {
        lv0 = _lv0;
    }

    function setLv1(uint256 _lv1) public onlyAdmin {
        lv1 = _lv1;
    }

    function setLv2(uint256 _lv2) public onlyAdmin {
        lv2 = _lv2;
    }

    function setLv3(uint256 _lv3) public onlyAdmin {
        lv3 = _lv3;
    }

    function setLv4(uint256 _lv4) public onlyAdmin {
        lv4 = _lv4;
    }

    function setLv5(uint256 _lv5) public onlyAdmin {
        lv5 = _lv5;
    }

    function setLv0Priv(uint256 _lv0Priv) public onlyAdmin {
        lv0Priv = _lv0Priv;
    }

    function setLv1Priv(uint256 _lv1Priv) public onlyAdmin {
        lv1Priv = _lv1Priv;
    }

    function setLv2Priv(uint256 _lv2Priv) public onlyAdmin {
        lv2Priv = _lv2Priv;
    }

    function setLv3Priv(uint256 _lv3Priv) public onlyAdmin {
        lv3Priv = _lv3Priv;
    }

    function setLv4Priv(uint256 _lv4Priv) public onlyAdmin {
        lv4Priv = _lv4Priv;
    }

    function setLv5Priv(uint256 _lv5Priv) public onlyAdmin {
        lv5Priv = _lv5Priv;
    }
    //设置平台提取募资资金时抽取的手续费比例
    function setPubCmsFee(uint256 _pubCmsFee) public onlyAdmin {
        pubCmsFee = _pubCmsFee;
    }

    //设置平台提取募资资金时抽取的手续费比例
    function setPrivCmsFee(uint256 _privCmsFee) public onlyAdmin {
        privCmsFee = _privCmsFee;
    }

    //设置转卖手续费比例
    function setPubTOutFee(uint256 _pubTOutFee) public onlyAdmin {
        pubTOutFee = _pubTOutFee;
    }

    function setPrivTOutFee(uint256 _privTOutFee) public onlyAdmin {
        privTOutFee = _privTOutFee;
    }

    //设置赎回违约金参数
    function setRedeemMinFee(uint256 _redeemMinFee) public onlyAdmin {
        redeemMinFee = _redeemMinFee;
    }

    function setRedeemMaxFee(uint256 _redeemMaxFee) public onlyAdmin {
        require(_redeemMaxFee > redeemMinFee, "maxFee must be greater than minFee");
        redeemMaxFee = _redeemMaxFee;
    }
    
    function setRedeemDay(uint256 _redeemDay) public onlyAdmin {
        require(_redeemDay > 0, "The redeemDay must be greater than 0");
        redeemDay = _redeemDay;
    }

    function setRedeemReduce(uint256 _redeemReduce) public onlyAdmin {
        require(_redeemReduce > 0, "The redeemReduce must be greater than 0");
        redeemReduce = _redeemReduce;
    }

    function setL0Range(uint256 _l0Range) public onlyAdmin {
       l0Range = _l0Range;
    }

    function setL1Range(uint256 _l1Range) public onlyAdmin {
        require(_l1Range > l0Range, "lv1 must be greater than lv0");
        l1Range = _l1Range;
    }

    function setL2Range(uint256 _l2Range) public onlyAdmin {
        require(_l2Range > l1Range, "lv2 must be greater than lv1");
        l2Range = _l2Range;
    }

    function setL3Range(uint256 _l3Range) public onlyAdmin {
        require(_l3Range > l2Range, "lv3 must be greater than lv2");
        l3Range = _l3Range;
    }

    function setL4Range(uint256 _l4Range) public onlyAdmin {
        require(_l4Range > l3Range, "lv4 must be greater than lv3");
       l4Range = _l4Range;
    }

    function setPubConf(uint256 _publicFee,
    uint256 _pubFixed,
    uint256 _lv0,
    uint256 _lv1,
    uint256 _lv2,
    uint256 _lv3,
    uint256 _lv4,
    uint256 _lv5,
    uint256 _pubCmsFee,
    uint256 _pubTOutFee) public onlyAdmin {
        publicFee = _publicFee;
        pubFixed = _pubFixed;
        lv0 = _lv0;
        lv1 = _lv1;
        lv2 = _lv2;
        lv3 = _lv3;
        lv4 = _lv4;
        lv5 = _lv5;
        pubCmsFee = _pubCmsFee;
        pubTOutFee = _pubTOutFee;
    }

    function setPrivConf(
    uint256 _privFixed,
    uint256 _lv0Priv,
    uint256 _lv1Priv,
    uint256 _lv2Priv,
    uint256 _lv3Priv,
    uint256 _lv4Priv,
    uint256 _lv5Priv,
    uint256 _privCmsFee,
    uint256 _privTOutFee) public onlyAdmin {
        privFixed = _privFixed;
        lv0Priv = _lv0Priv;
        lv1Priv = _lv1Priv;
        lv2Priv = _lv2Priv;
        lv3Priv = _lv3Priv;
        lv4Priv = _lv4Priv;
        lv5Priv = _lv5Priv;
        privCmsFee = _privCmsFee;
        privTOutFee = _privTOutFee;
    }

    function setOtConf(
    address _feeAddr,
    uint256 _redeemMinFee,
    uint256 _redeemMaxFee,
    uint256 _redeemDay,
    uint256 _redeemReduce) public onlyAdmin {
        feeAddr = _feeAddr;
        redeemMinFee = _redeemMinFee;
        redeemMaxFee = _redeemMaxFee;
        redeemDay = _redeemDay;
        redeemReduce = _redeemReduce;
    }

    function getTokens() public view returns (address[] memory) {
        return tokens;
    }

    //获取需要支付的费用
    function getRedeemFee(uint256 amount, uint256 subsTime) public view returns (uint256) {
        uint256 timeLen = block.timestamp-subsTime;
        uint256 redduceFee = timeLen.div(redeemDay.mul(86400)).mul(redeemReduce);
        uint256 payFee = 0;
        if (redduceFee>=redeemMaxFee) {
            payFee = redeemMinFee;
        } else {
            payFee = redeemMaxFee.sub(redduceFee);
        }

        if (payFee<redeemMinFee) {
            payFee = redeemMinFee;
        }
        return amount.mul(payFee).div(10000);
    }

    //获取认购时所需支付的手续费
    function lv(address _token, uint256 _fundType, uint256 _amount) public view returns (uint256) {
        if(_fundType==1) {
            if(_token==usdtAddr) {
                return pubFixed;
            } else {
                if(_amount<l0Range*one) {
                    return lv0;
                } else if(_amount>=l0Range*one&&_amount<l1Range*one) {
                    return lv1;
                } else if(_amount>=l1Range*one&&_amount<l2Range*one) {
                    return lv2;
                } else if(_amount>=l2Range*one&&_amount<l3Range*one) {
                    return lv3;
                } else if(_amount>=l3Range*one&&_amount<l4Range*one) {
                    return lv4;
                } else if(_amount>=l4Range*one) {
                    return lv5;
                }
            }
        } else {
            if(_token==usdtAddr) {
                return privFixed;
            } else {
                if(_amount<l0Range*one) {
                    return lv0Priv;
                } else if(_amount>=l0Range*one&&_amount<l1Range*one) {
                    return lv1Priv;
                } else if(_amount>=l1Range*one&&_amount<l2Range*one) {
                    return lv2Priv;
                } else if(_amount>=l2Range*one&&_amount<l3Range*one) {
                    return lv3Priv;
                } else if(_amount>=l3Range*one&&_amount<l4Range*one) {
                    return lv4Priv;
                } else if(_amount>=l4Range*one) {
                    return lv5Priv;
                }
            }
        }
        return 0;
    }

    function lvLevel(uint256 _amount) public view returns (string memory) {
        if(_amount<l0Range*one) {
            return "Lv0";
        } else if(_amount>=l0Range*one&&_amount<l1Range*one) {
            return "Lv1";
        } else if(_amount>=l1Range*one&&_amount<l2Range*one) {
            return "Lv2";
        } else if(_amount>=l2Range*one&&_amount<l3Range*one) {
            return "Lv3";
        } else if(_amount>=l3Range*one&&_amount<l4Range*one) {
            return "Lv4";
        } else if(_amount>=l4Range*one) {
            return "Lv5";
        }
        return "Lv0";
    }

    //获取价格
    function getPrice(address _tokenIn) public view returns (uint256, uint8) {
        if (_tokenIn==address(0)) {
            _tokenIn = wethAddr;
        }
        uint8 dec = IEIP20(_tokenIn).decimals();
        uint256 oneUnit = 10**uint256(dec);
        if (_tokenIn==usdtAddr) {
            return (oneUnit, dec);
        }
        address[] memory paths;
        paths = new address[](2);
        paths[0] = _tokenIn;
        paths[1] = usdtAddr;
        uint256[] memory amountsExpected = IUniswapV2Router02(routerAddr).getAmountsOut(oneUnit, paths);
        return (amountsExpected[1], dec);
    }
    //佣金
    function fee(uint256 _fundType) public view returns (uint256) {
        return _fundType==1?pubCmsFee:privCmsFee;
    }
    //转卖手续费
    function transOutFee(uint256 _fundType) public view returns (uint256) {
        return _fundType==1?pubTOutFee:privTOutFee;
    }

    receive() external payable {}

    uint256[49] private __gap;
}