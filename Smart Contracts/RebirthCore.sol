// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

contract RebirthCore{
    //Variable Declarations
    address SRBH_Admin; //TODO: Preset?
    ERC20 SRBH; //TODO: Change to ERC20
    ERC20 RelaunchShares;
    uint256[] public OpenPools;
    //Struct-Enum Declarations

    enum AlternativePayoutOption { SRBHTokens, NFTFreemints, RelaunchShares }

    struct RebirthPool{
        address TokenAddress;
        address PairAddress;
        uint256 PoolOpeningTime;
        uint256 PoolClosingTime;
        uint256 SoftCap;
        uint256 TotalEtherDeposited;
    }

    //Mapping Declarations
    mapping(uint256 => RebirthPool) public Pools;
    mapping(uint256 => mapping(address => uint256)) public PoolDeposits;
    mapping(uint256 => uint256) OpenPoolsIndexer;
    mapping(ui => uint2)


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

    //Public Functions
    //Deposit function for ether only, payable and amount is determined by msg.value
    function DepositEther(uint256 PoolID) public payable {
        require(block.timestamp >= Pools[PoolID].PoolOpeningTime && block.timestamp <= Pools[PoolID].PoolClosingTime, "Pool is not open");
        PoolDeposits[PoolID][msg.sender] += msg.value;
        Pools[PoolID].TotalEtherDeposited += msg.value;
    }

    //TODO: Deposit function for Rebirth Shares 

    //OnlyOwner Functions
    function CreatePool(address TokenAddress, address PairAddress, uint256 HoursTillOpen, uint256 LenghtInHours, uint256 SoftCap) public onlyOwner {
        uint256 PoolID = OpenPools.length;
        uint256 StartTime = (block.timestamp + (HoursTillOpen * 3600));
        uint256 EndTime = StartTime + (LenghtInHours * 3600);
        Pools[PoolID] = RebirthPool(TokenAddress, PairAddress, StartTime, EndTime, SoftCap, 0);
        AddRemoveActivePool(PoolID, true);
    }

    function setAdmin(address _newAdmin) public onlyOwner {
        SRBH_Admin = _newAdmin;
    }

    //Internal Functions
    function AddRemoveActivePool(uint256 PoolID, bool AddRemove) internal {
        if(AddRemove){
            OpenPools.push(PoolID);
            OpenPoolsIndexer[PoolID] = OpenPools.length - 1;
        }
        else{
            OpenPools[OpenPoolsIndexer[PoolID]] = OpenPools[OpenPools.length - 1];
            OpenPools.pop();
        }
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