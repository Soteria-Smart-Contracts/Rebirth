// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

//Copilot, whats left to finish this contract is the following:
//A function that allows users to deposit memecoins (in this case token address in the rebirthpool struct), store that value in the mapping
//A function that allows the admin to close a pool once the time has passed, then sell the tokens for eth, and buy back RBH with the eth, then it will create a new ERC20 token with the name and symbol of the old memecoin, and create a new RBH/Memecoin pair on uniswap, send the liquidity tokens to the zero address, 

contract RebirthProtocolCore{
    //Variable Declarations
    address RBH_Admin;
    ERC20 RBH;
    IUniswapV2Factory UniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Router02 UniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); 
    address FreemintContract; //TODO: Set up in alternative payouts
    uint256[] public OpenPools;
    //Struct-Enum Declarations

    enum AlternativePayoutOption { RBHTokens, NFTFreemints, RelaunchShares }

    struct RebirthPool{
        string Name;
        string Symbol;
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
    // function DepositEther(uint256 PoolID) public payable { TODO: This is old, do we need?
    //     require(block.timestamp >= Pools[PoolID].PoolOpeningTime && block.timestamp <= Pools[PoolID].PoolClosingTime, "Pool is not open");
    //     PoolDeposits[PoolID][msg.sender] += msg.value;
    //     Pools[PoolID].TotalEtherDeposited += msg.value;
    // }

    //TODO: Rebirth shares functionality
    //TODO: Deposit function for Rebirth Shares 
    //TODO: New RBH live pair functionality and how its gonna fkin work

    //OnlyOwner Functions
    function CreatePool(address TokenAddress, address PairAddress, uint256 HoursTillOpen, uint256 LenghtInHours, uint256 SoftCap, string memory TokenName, string memory TokenSymbol) public onlyOwner {
        uint256 PoolID = OpenPools.length;
        uint256 StartTime = (block.timestamp + (HoursTillOpen * 3600));
        uint256 EndTime = StartTime + (LenghtInHours * 3600);
        Pools[PoolID] = RebirthPool(TokenName, TokenSymbol, TokenAddress, PairAddress, StartTime, EndTime, SoftCap, 0, false);
        AddRemoveActivePool(PoolID, true);
    }

    function setAdmin(address _newAdmin) public onlyOwner {
        RBH_Admin = _newAdmin;
    }

    function SetFreemintContract(address _FreemintContract) public onlyOwner {
        FreemintContract = _FreemintContract;
    }

    //Only freemint contract

    function Freeminted(address User, uint256 Amount) external {
        require(msg.sender == FreemintContract, "Only freemint contract can call this function");
        require(NFT_Freemints[User] > 0 && NFT_Freemints[User] >= Amount, "User has no freemints");

        NFT_Freemints[User] -= Amount;
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

interface IUniswapV2Router02{
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

     function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}