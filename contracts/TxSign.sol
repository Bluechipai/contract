// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TxSign is OwnableUpgradeable {

    address private authorizer;

    mapping(uint256 => bool) public saltUsed;

    string private constant DOMAIN_NAME = "IDO Protocol";

    bytes32 private DOMAIN_SEPARATOR;

    bytes32 private constant PERMIT_TYPEHASH = keccak256(
        abi.encodePacked("Permit(address signer,uint256 fundType,uint256 quantity,uint256 price,uint256 pledgeReward,uint256 deadline,uint256 salt)")
    );

    bytes32 private constant TYPEHASH_WITHDRAW = keccak256(
        abi.encodePacked("Permit(address signer,address account,address usdt,uint256 fundraisinNo,uint256 deadline,uint256 salt)")
    );

    bytes32 private constant TYPEHASH_INVITE_REWARDS = keccak256(
        abi.encodePacked("Permit(address signer,address account,uint256 amount,uint256 deadline,uint256 salt)")
    );

    function initialize(address _authorizer) public virtual initializer {
         __Ownable_init();
        authorizer = _authorizer;
    }

    function setContractAddr(address _contractAddr) public onlyOwner {
        require(_contractAddr != address(0), "Invalid contract address");
        
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,address verifyingContract)"),
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes("1")),
                _contractAddr
            )
        );
    }

    function setAuthorizer(address _authorizer) public onlyOwner {
        require(_authorizer != address(0), "invalid authorizer");
        authorizer = _authorizer;
    }
    
    function permit(
        uint256 fundType,
        uint256 quantity,
        uint256 price,
        uint256 pledgeReward,
        uint256 deadline,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(saltUsed[salt] == false, "Salt has be used");
        require(deadline == 0 || block.timestamp <= deadline, "permit-expired");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, authorizer, fundType, quantity, price, pledgeReward, deadline, salt))
            )
        );
        
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == authorizer, "invalid signature");

        saltUsed[salt] = true;
    }

    function permitWithdraw(
        address account,
        address usdt,
        uint256 fundraisinNo,
        uint256 deadline,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(saltUsed[salt] == false, "Salt has be used");
        require(deadline == 0 || block.timestamp <= deadline, "permit-expired");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(TYPEHASH_WITHDRAW, authorizer, account, usdt, fundraisinNo, deadline, salt))
            )
        );
        
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == authorizer, "invalid signature");

        saltUsed[salt] = true;
    }

    function permitInviteRewards(
        address account,
        uint256 amount,
        uint256 deadline,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(saltUsed[salt] == false, "Salt has be used");
        require(deadline == 0 || block.timestamp <= deadline, "permit-expired");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(TYPEHASH_INVITE_REWARDS, authorizer, account, amount, deadline, salt))
            )
        );
        
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == authorizer, "invalid signature");

        saltUsed[salt] = true;
    }
}
