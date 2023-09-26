// SPDX-License-Identifier: UNLICENSE
pragma solidity 0.8.19;


contract RebirthProtocolCore{
    //Variable Declarations
    address public RBH_SuperAdmin;
    ERC20 public RBH;
    IUniswapV2Factory UniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Router02 UniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public FreemintContract;
    uint256[] public OpenPools;
    uint256[] public ClosedPools;
    uint256 internal PoolIncrement;
    //Struct-Enum Declarations

    enum AlternativePayoutOption { RBHTokens, NFTFreemints, RelaunchShares }

    struct RebirthPool{
        string Name;
        string Symbol;
        address TokenAddress;
        address RebirthedTokenAddress;
        address PairAddress;
        uint256 PoolOpeningTime;
        uint256 PoolClosingTime;
        uint256 SoftCap;
        uint256 MemecoinsPerRelaunchShare;
        uint256 TotalTokensDeposited;
        bool PoolSuccessful;
        bool PoolClosed;
    }

    struct UserPoolDetails{
        uint256 AmountDeposited;
        AlternativePayoutOption AlternatePayoutChoice;
        bool PreviouslyDeposited;
        bool Claimed;
    }

    //Mapping Declarations
    mapping(uint256 => RebirthPool) public Pools;
    mapping(uint256 => mapping(address => UserPoolDetails)) public PoolDeposits;
    mapping(address => uint256[]) public YourPools;
    mapping(uint256 => uint256) internal OpenPoolsIndexer;
    mapping(address => bool) public Admins;
    mapping(address => uint256) public RelaunchShares;
    mapping(address => uint256) public NFT_Freemints;

    //Event Declarations

    //Modifier Declarations
    modifier onlyAdmin() {
        require(Admins[msg.sender], "Only admins can call this function");
        _;
    }

    modifier onlySuperAdmin() {
        require(msg.sender == RBH_SuperAdmin, "Only super admin can call this function");
        _;
    }

    //Constructor
    constructor(address _RBH) {
        RBH_SuperAdmin = msg.sender;
        Admins[msg.sender] = true;
        RBH = ERC20(_RBH);
    }

    //Public Functions

    function DepositTokens(uint256 PoolID, uint256 Amount, AlternativePayoutOption AlternatePayoutChoice) public {
        require(block.timestamp >= Pools[PoolID].PoolOpeningTime && block.timestamp <= Pools[PoolID].PoolClosingTime, "Pool is not open");
        require(ERC20(Pools[PoolID].TokenAddress).transferFrom(msg.sender, address(this), Amount), "Transfer failed");

        if(!PoolDeposits[PoolID][msg.sender].PreviouslyDeposited){
            require(Amount >= 1000); //Requires first time depositors to deposit some amount of token
            YourPools[msg.sender].push(PoolID);
        }

        PoolDeposits[PoolID][msg.sender].AmountDeposited += Amount;
        PoolDeposits[PoolID][msg.sender].AlternatePayoutChoice = AlternatePayoutChoice;
        PoolDeposits[PoolID][msg.sender].PreviouslyDeposited = true;
        Pools[PoolID].TotalTokensDeposited += Amount;
    }

    function DepositRelaunchShares(uint256 PoolID, uint256 Amount, AlternativePayoutOption AlternatePayoutChoice) public {
        require(block.timestamp >= Pools[PoolID].PoolOpeningTime && block.timestamp <= Pools[PoolID].PoolClosingTime, "Pool is not open");
        require(Amount > 0, "Cannot deposit zero relaunch shares");
        require(RelaunchShares[msg.sender] >= Amount, "Not enough relaunch shares");

        if(!PoolDeposits[PoolID][msg.sender].PreviouslyDeposited){
            YourPools[msg.sender].push(PoolID);
        }

        RelaunchShares[msg.sender] -= Amount;

        address[] memory Path = new address[](2);
        Path[0] = UniswapRouter.WETH();
        Path[1] = Pools[PoolID].TokenAddress;

        uint256 MemecoinsPerRelaunchShare = UniswapRouter.getAmountsOut(0.001 ether, Path)[1];
        uint256 DepositEquivalent = MemecoinsPerRelaunchShare * Amount;

        PoolDeposits[PoolID][msg.sender].AmountDeposited += DepositEquivalent;
        PoolDeposits[PoolID][msg.sender].AlternatePayoutChoice = AlternatePayoutChoice;
        PoolDeposits[PoolID][msg.sender].PreviouslyDeposited = true;
        Pools[PoolID].TotalTokensDeposited += DepositEquivalent;
    }

    function ClaimPool(uint256 PoolID) public {
        require(Pools[PoolID].PoolClosed, "Pool is still open");
        require(!PoolDeposits[PoolID][msg.sender].Claimed, "Already claimed");
        require(PoolDeposits[PoolID][msg.sender].AmountDeposited > 0, "No tokens deposited");

        if(Pools[PoolID].PoolSuccessful){
            //Send the new contract tokens to the user
            ERC20 NewMemecoin = ERC20(Pools[PoolID].RebirthedTokenAddress);
            NewMemecoin.transfer(msg.sender, PoolDeposits[PoolID][msg.sender].AmountDeposited);
        }
        else{
            //execute alternative payout option, nft freemints cost 10x relaunch shares
            uint256 UserRelaunchSharesEquivalent = PoolDeposits[PoolID][msg.sender].AmountDeposited / Pools[PoolID].MemecoinsPerRelaunchShare;
            if(PoolDeposits[PoolID][msg.sender].AlternatePayoutChoice == AlternativePayoutOption.RBHTokens){
                //Send RBH tokens to the user
                address[] memory Path = new address[](2);
                Path[0] = UniswapRouter.WETH();
                Path[1] = address(RBH);

                uint256 RBHpayout = (UniswapRouter.getAmountsOut(0.001 ether * UserRelaunchSharesEquivalent,Path)[1] * 110) / 100;
                RBH.transfer(msg.sender, RBHpayout);
            }
            else if(PoolDeposits[PoolID][msg.sender].AlternatePayoutChoice == AlternativePayoutOption.NFTFreemints){
                NFT_Freemints[msg.sender] += UserRelaunchSharesEquivalent / 10; //Watch out, could be 0 if memecoins are worth less than 0.01 Ether
            }
            else if(PoolDeposits[PoolID][msg.sender].AlternatePayoutChoice == AlternativePayoutOption.RelaunchShares){
                RelaunchShares[msg.sender] += UserRelaunchSharesEquivalent;
            }
        }

        PoolDeposits[PoolID][msg.sender].Claimed = true;
    }

    //OnlyOwner Functions
    function CreatePool(address TokenAddress, address PairAddress, uint256 HoursTillOpen, uint256 LenghtInHours, uint256 SoftCap, string memory TokenName, string memory TokenSymbol) public onlyAdmin {
        uint256 PoolID = PoolIncrement;
        PoolIncrement++;
        uint256 StartTime = (block.timestamp + (HoursTillOpen * 60)); //TODO: EDIT TIMES BACK TO 3600
        uint256 EndTime = StartTime + (LenghtInHours * 60); //TODO: EDIT TIMES 3600
        Pools[PoolID] = RebirthPool(TokenName, TokenSymbol, TokenAddress, address(0), PairAddress, StartTime, EndTime, SoftCap, 0, 0, false, false);

        address[] memory Path = new address[](2);
        Path[0] = UniswapRouter.WETH();
        Path[1] = Pools[PoolID].TokenAddress;

        uint256 MemecoinsPerRelaunchShare = UniswapRouter.getAmountsOut(0.001 ether, Path)[1];
        Pools[PoolID].MemecoinsPerRelaunchShare = MemecoinsPerRelaunchShare;

        AddRemoveActivePool(PoolID, true);
    }

    function ClosePool(uint256 PoolID) public onlyAdmin {
        require(block.timestamp >= Pools[PoolID].PoolClosingTime, "Pool is still open");
        require(Pools[PoolID].PoolClosed == false, "Pool is already closed");
        AddRemoveActivePool(PoolID, false);

        if (Pools[PoolID].TotalTokensDeposited < Pools[PoolID].SoftCap){
            Pools[PoolID].PoolSuccessful = false;
            ERC20 Token = ERC20(Pools[PoolID].TokenAddress);
            Token.transfer(RBH_SuperAdmin, Token.balanceOf(address(this)));
        }
        else{
            Pools[PoolID].PoolSuccessful = true;

            ERC20 Token = ERC20(Pools[PoolID].TokenAddress);
            Token.approve(address(UniswapRouter), Token.balanceOf(address(this)));

            address[] memory Path = new address[](2);
            Path[0] = Pools[PoolID].TokenAddress;
            Path[1] = UniswapRouter.WETH();

            UniswapRouter.swapExactTokensForETH(Token.balanceOf(address(this)), 0, Path, address(this), block.timestamp + 300);

            //Buy back RBH with wrapped eth
            Path[0] = UniswapRouter.WETH();
            Path[1] = address(RBH);

            uint256 RBH_TradeAmount = UniswapRouter.getAmountsOut(address(this).balance, Path)[1];
            payable(RBH_SuperAdmin).transfer(address(this).balance);

            //Create new ERC20 token with the name and symbol of the old memecoin
            uint256 BalanceToLiquidity = Pools[PoolID].TotalTokensDeposited;
            RebirthedToken NewToken = new RebirthedToken(((Pools[PoolID].TotalTokensDeposited * 210) / 100), Pools[PoolID].Name, Pools[PoolID].Symbol);
            Pools[PoolID].RebirthedTokenAddress = address(NewToken);
            NewToken.transfer(RBH_SuperAdmin, (BalanceToLiquidity / 10));

            //Create new RBH/Memecoin pair on uniswap, send the liquidity tokens to the zero address
            IUniswapV2Pair NewTokenPair = IUniswapV2Pair(UniswapFactory.createPair(address(RBH), address(NewToken)));
            NewToken.approve(address(UniswapRouter), BalanceToLiquidity);
            RBH.approve(address(UniswapRouter), RBH_TradeAmount);
            UniswapRouter.addLiquidity(address(RBH), address(NewToken), RBH_TradeAmount, BalanceToLiquidity, 0, 0, address(this), (block.timestamp + 300));
            ERC20(address(NewTokenPair)).transfer(address(0), ERC20(address(NewTokenPair)).balanceOf(address(this)));
        }

        Pools[PoolID].PoolClosed = true;
        ClosedPools.push(PoolID);
    }

    function setSuperAdmin(address _newAdmin) public onlySuperAdmin {
        RBH_SuperAdmin = _newAdmin;
    }

    function AddRemoveAdmin(address _newAdmin, bool AddRemove) public onlySuperAdmin {
        Admins[_newAdmin] = AddRemove;
    }

    function SetFreemintContract(address _FreemintContract) public onlySuperAdmin {
        FreemintContract = _FreemintContract;
    }

    function WithdrawRBH() public onlySuperAdmin {
        RBH.transfer(RBH_SuperAdmin, RBH.balanceOf(address(this)));
    }

    //Only freemint contract
    function Freeminted(address User, uint256 Amount) external {
        require(msg.sender == FreemintContract, "Only freemint contract can call this function");
        require(NFT_Freemints[User] > 0 && NFT_Freemints[User] >= Amount, "User has no freemints or requested amount is too high");

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

    //View Functions
    function GetOpenPools() public view returns (uint256[] memory){
        return OpenPools;
    }

    function GetClosedPools() public view returns (uint256[] memory){
        return ClosedPools;
    }

    function GetPoolDetails(uint256 PoolID) public view returns (RebirthPool memory){
        return Pools[PoolID];
    }

    function GetUserPoolDetails(uint256 PoolID, address User) public view returns (UserPoolDetails memory){
        return PoolDeposits[PoolID][User];
    }

    function GetUserPools(address User) public view returns (uint256[] memory){
        return YourPools[User];
    }

    //Receive function
    receive() external payable {
    }
}

//This next contract needs to be able to accept any memecoin with any ethereum exchange amount 
contract RebirthLiquidator{

}


//TODO: Update interfaces depending on existing contracts

contract RebirthedToken {
    uint256 public tokenCap;
    uint256 public totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;
    address private ZeroAddress;
    //variable Declarations
    

    event Transfer(address indexed from, address indexed to, uint256 value);    
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BurnEvent(address indexed burner, uint256 indexed buramount);
    event ManageMinterEvent(address indexed newminter);
    //Event Declarations 
    
    mapping(address => uint256) public balances;

    mapping(address => mapping (address => uint256)) public allowance;
    
    constructor(uint256 _TokenCap, string memory _name, string memory _symbol){
        tokenCap = _TokenCap;
        totalSupply = 0;
        name = _name;
        symbol = _symbol;
        decimals = 18;
        Mint(msg.sender, _TokenCap);
    }
    
    function balanceOf(address Address) public view returns (uint256 balance){
        return balances[Address];
    }

    function approve(address delegate, uint _amount) public returns (bool) {
        allowance[msg.sender][delegate] = _amount;
        emit Approval(msg.sender, delegate, _amount);
        return true;
    }
    //Approves an address to spend your coins

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool) {
        require(_amount <= balances[_from]);    
        require(_amount <= allowance[_from][msg.sender]);
    
        balances[_from] = balances[_from]-(_amount);
        allowance[_from][msg.sender] = allowance[_from][msg.sender]-(_amount);
        balances[_to] = balances[_to]+(_amount);
        emit Transfer(_from, _to, _amount);
        return true;
    }
    //Transfer From an other address


    function transfer(address _to, uint256 _amount) public returns (bool) {
        require(_amount <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender]-(_amount);
        balances[_to] = balances[_to]+(_amount);
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }


    function Mint(address _MintTo, uint256 _MintAmount) internal {
        require (totalSupply+(_MintAmount) <= tokenCap);
        balances[_MintTo] = balances[_MintTo]+(_MintAmount);
        totalSupply = totalSupply+(_MintAmount);
        ZeroAddress = 0x0000000000000000000000000000000000000000;
        emit Transfer(ZeroAddress ,_MintTo, _MintAmount);
    } //Can only be used on deploy, view Internal 


    function Burn(uint256 _BurnAmount) public {
        require (balances[msg.sender] >= _BurnAmount);
        balances[msg.sender] = balances[msg.sender]-(_BurnAmount);
        totalSupply = totalSupply-(_BurnAmount);
        ZeroAddress = 0x0000000000000000000000000000000000000000;
        emit Transfer(msg.sender, ZeroAddress, _BurnAmount);
        emit BurnEvent(msg.sender, _BurnAmount);
        
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