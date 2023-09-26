contract RebirthLiquidator {
    address public RBH_SuperAdmin;
    address public RebirthCoreAddress;
    IUniswapV2Router02 public uniswapRouter; 
    ERC20 public RBH;
    uint256 public TotalEtherLiquidated;

    mapping(address => mapping(address => UserRBHLiquidation)) public UserRBHLiquidations;
    mapping(address => address[]) public AllUserLiquidations;

    struct UserRBHLiquidation{
        uint256 RBHPayout;
        uint256 ClaimTime;
    }

    enum AlternativePayoutOption { RBHTokens, NFTFreemints, RelaunchShares }

    constructor(address rebirthCoreAddress) {
        RebirthCoreAddress = rebirthCoreAddress;
        RBH_SuperAdmin = RebirthProtocolCore(payable(RebirthCoreAddress)).RBH_SuperAdmin();
        uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        RBH = ERC20(RebirthProtocolCore(payable(RebirthCoreAddress)).RBH());
    }

    // Function to liquidate memecoins, and allow users to select which of the three options they want to claim
    function Liquidate(address memecoinAddress, uint256 amount, AlternativePayoutOption PayoutChoice) external {
        require(ERC20(uniswapRouter.WETH()).balanceOf(IUniswapV2Factory(uniswapRouter.factory()).getPair(memecoinAddress, uniswapRouter.WETH())) > 0, "Pair doesn't exist or has no liquidity");
        require(ERC20(memecoinAddress).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        require(UserRBHLiquidations[msg.sender][memecoinAddress].ClaimTime == 0, "Await or claim existing liquidation on this token");

        RebirthProtocolCore(payable(RebirthCoreAddress)).AddUserToCountAndParticipated(msg.sender);

        address[] memory path = new address[](2);
        path[0] = memecoinAddress;
        path[1] = uniswapRouter.WETH();

        uniswapRouter.swapExactTokensForETH(amount,0, path, address(this), block.timestamp + 300);
        uint256 wETHIn = address(this).balance;
        unchecked{
            TotalEtherLiquidated += wETHIn;
        }
        payable(RBH_SuperAdmin).transfer(address(this).balance);

        //handle payout choice
        if(PayoutChoice == AlternativePayoutOption.RBHTokens){
            //In this case, calculate the total RBH payout but then set it to a lock  of 10 days for the user to await before being able to claim, dont forget to set the path to rbh from the weth amount extracted (wETHin)
            path[0] = uniswapRouter.WETH();
            path[1] = address(RBH);

            uint256 RBH_TradeAmount = uniswapRouter.getAmountsOut(wETHIn, path)[1];
            UserRBHLiquidations[msg.sender][memecoinAddress].RBHPayout = (RBH_TradeAmount * 110) / 100;
            UserRBHLiquidations[msg.sender][memecoinAddress].ClaimTime = block.timestamp + 864000;
        }
        else if(PayoutChoice == AlternativePayoutOption.NFTFreemints){
            RebirthProtocolCore(payable(RebirthCoreAddress)).AddFreemint(msg.sender, amount / 10);
        }
        else if(PayoutChoice == AlternativePayoutOption.RelaunchShares){
            RebirthProtocolCore(payable(RebirthCoreAddress)).AddRelaunchShare(msg.sender, amount / 1000);
        }
    }

    //Function to claim RBH tokens from a liquidation
    function ClaimRBH(address memecoinAddress) external {
        require(UserRBHLiquidations[msg.sender][memecoinAddress].ClaimTime != 0, "No liquidation to claim");
        require(UserRBHLiquidations[msg.sender][memecoinAddress].ClaimTime <= block.timestamp, "Await liquidation to be claimable");

        //transferfrom rbh from rebirthcore 
        RBH.transferFrom(RebirthCoreAddress, msg.sender, UserRBHLiquidations[msg.sender][memecoinAddress].RBHPayout);
        UserRBHLiquidations[msg.sender][memecoinAddress].RBHPayout = 0;
        UserRBHLiquidations[msg.sender][memecoinAddress].ClaimTime = 0;
    }

    //create view functions to get all liquidations for a user, and to get the details of a specific liquidation
    function GetUserLiquidations(address User) public view returns (address[] memory){
        return AllUserLiquidations[User];
    }

    function GetUserLiquidationDetails(address User, address Memecoin) public view returns (UserRBHLiquidation memory){
        return UserRBHLiquidations[User][Memecoin];
    }

}