// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

contract RebirthCore{
    //Variable Declarations
    address RBH_Admin; //TODO: Preset?
    ERC20 RBH;
    IUniswapV2Factory UniswapFactory;
    address FreemintContract; //TODO: Set up in alternative payouts
    uint256[] public OpenPools;
    //Struct-Enum Declarations

    enum AlternativePayoutOption { RBHTokens, NFTFreemints, RelaunchShares }

    struct RebirthPool{
        address TokenAddress;
        address PairAddress;
        uint256 PoolOpeningTime;
        uint256 PoolClosingTime;
        uint256 SoftCap;
        uint256 TotalEtherDeposited;
        bool PoolSuccessful;
    }

    //Mapping Declarations
    mapping(uint256 => RebirthPool) public Pools;
    mapping(uint256 => mapping(address => uint256)) public PoolDeposits;
    mapping(uint256 => uint256) OpenPoolsIndexer;
    mapping(address => uint256) NFT_Freemints; //TODO: Set up in alternative payouts


    //Event Declarations

    //Modifier Declarations
    modifier onlyOwner() {
        require(msg.sender == RBH_Admin);
        _;
    }

    //Constructor
    constructor(address _RBH) {
        RBH_Admin = msg.sender;
        RBH = ERC20(_RBH);
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
        Pools[PoolID] = RebirthPool(TokenAddress, PairAddress, StartTime, EndTime, SoftCap, 0, false);
        AddRemoveActivePool(PoolID, true);
    }

    function setAdmin(address _newAdmin) public onlyOwner {
        RBH_Admin = _newAdmin;
    }

    function SetFreemintContract(address _FreemintContract) public onlyOwner {
        FreemintContract = _FreemintContract;
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

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}