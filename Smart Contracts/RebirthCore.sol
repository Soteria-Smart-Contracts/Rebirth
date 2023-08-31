// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

contract RebirthCore{
    //Variable Declarations
    address SRBH_Admin; //TODO: Preset?
    ERC20 SRBH; //TODO: Change to ERC20
    ERC20 RelaunchShares;

    //Struct-Enum Declarations

    enum AlternativePayoutOption { SRBHTokens, NFTFreemints, RelaunchShares }

    struct PoolParameters{
        address TokenAddress;
        address PairAddress;
        uint256 PoolOpeningTime;
        uint256 PoolClosingTime;
        uint256 softCap;
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
        SRBH = ERC20(_SRBH);
    }

    //OnlyOwner Functions
    function setAdmin(address _newAdmin) public onlyOwner {
        SRBH_Admin = _newAdmin;
    }
}

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint);
} 