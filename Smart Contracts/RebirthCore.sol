// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

contract RebirthCore{
    //Variable Declarations
    address SRBH_Admin; //TODO: Preset?
    address SRBH; //TODO: Change to ERC20

    //Struct-Enum Declarations

    enum AlternativePayoutOption { SRBHTokens, NFTFreemints, RelaunchShares }

    struct PoolParameters{
        
    }

    //Mapping Declarations

    //Event Declarations

    //Modifier Declarations
    modifier onlyOwner() {
        require(msg.sender == SRBH_Admin);
        _;
    }

    //Constructor
    constructor(address _SRBH) {
        SRBH_Admin = msg.sender;
        SRBH = _SRBH;
    }

    //OnlyOwner Functions
    function setAdmin(address _newAdmin) public onlyOwner {
        SRBH_Admin = _newAdmin;
    }
}