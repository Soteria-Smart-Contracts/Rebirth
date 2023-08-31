// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

contract RebirthCore{
    //Variable Declarations
    address SRBH_Admin; //TODO: Preset?
    ERC20 SRBH; //TODO: Change to ERC20
    ERC20 RelaunchShares;
    uint256[] public OpenPools;
    //Create a fisher yates shuffle array and function to add or remove pools from the array
    

    //Struct-Enum Declarations

    enum AlternativePayoutOption { SRBHTokens, NFTFreemints, RelaunchShares }

    struct RebirthPool{
        address TokenAddress;
        address PairAddress;
        uint256 PoolOpeningTime;
        uint256 PoolClosingTime;
        uint256 softCap;
    }

    //Mapping Declarations
    mapping(uint256 => RebirthPool) public Pools;

    //Event Declarations

    //Modifier Declarations
    modifier onlyOwner() {
        require(msg.sender == SRBH_Admin);
        _;
    }

    //Constructor
    constructor(address _SRBH, address _RelaunchShares) {
        SRBH_Admin = msg.sender;
        SRBH = ERC20(_SRBH);
        RelaunchShares = ERC20(_RelaunchShares);
    }

    //OnlyOwner Functions
    function setAdmin(address _newAdmin) public onlyOwner {
        SRBH_Admin = _newAdmin;
    }
}

//TODO: Update interfaces depending on existing contracts

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint);
} 

interface ERC721{
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}