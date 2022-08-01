// version 1 deprecated
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/VVS/IVVSRouter02.sol";
import "./interfaces/Tectonic/TErc20Interface.sol"; 
import "./interfaces/Tectonic/TEtherInterface.sol"; 
import "./interfaces/Tectonic/TectonicCoreInterface.sol"; 
import "./token/Goju.sol";
import "hardhat/console.sol";

contract Jujutsu is Ownable {
  using SafeMath for uint;
  using SafeERC20 for IERC20;

  struct ShortOrder {
    uint id;
    address targetToken;
    address collateralToken;
    uint targetAmount;
    uint collateralAmount;
    uint tCollateralAmount;
    uint shortTokenAmount;
  }

  event InitiateShort(address indexed user, address indexed targetToken, uint targetAmount, address indexed collateralToken);

  mapping(address => ShortOrder[]) public userShortOrders;
  mapping(address => mapping(uint => ShortOrder)) public userShortOrder;
  mapping(address => uint) public userNextShortId;

  address private constant USDC = 0xc21223249CA28397B4B6541dfFaEcC539BfF0c59;
  address private constant WCRO = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23;

  address[] public marketJoined;
  // token addr map to tToken address
  mapping(address => address) public marketsMapping;
  mapping(address => AggregatorV3Interface) public tokenOracle;
  mapping(address => bool) public validCollateral;
  mapping(address => uint) public tokenDecimals;
  mapping(address => bool) public isStableCoin;
  mapping(address => mapping(address => uint)) public userBorrowed; // [user][token]
  // mapping(address => mapping(address => uint)) public userCollateral; // [user][tToken]

  Goju public immutable shortToken;
  AggregatorV3Interface croOracle;
  IVVSRouter02 vvsRouter;
  TectonicCoreInterface tectonic;
  

  constructor (address _shortToken, address _vvs, address _tectonic) {
    shortToken = Goju(_shortToken);
    vvsRouter = IVVSRouter02(_vvs);
    tectonic = TectonicCoreInterface(_tectonic);
  }

  /// @notice Set the token address to the tToken address
  /// @dev CRO native token is represented in 0x00..0 
  function initialize(
    address[] calldata _tokens,
    address[] calldata _tTokens,
    uint[] calldata _decimals
  ) external onlyOwner {
    for (uint i; i < _tokens.length; i++) {
      marketsMapping[_tokens[i]] = _tTokens[i];
      tokenDecimals[_tokens[i]] = _decimals[i];
    }
  }
  
  // TUSD, USDC
  function setValidCollateral(address _token) external onlyOwner {
    validCollateral[_token] = true;
  }

  function setStableCoin(address _token) external onlyOwner {
    isStableCoin[_token] = true;
  }

  function registerNativeCurrencyOracle(AggregatorV3Interface _oracleAddress) external onlyOwner {
    require(_oracleAddress.decimals() != 0, "Oracle returns 0 decimals");
    (uint80 roundId, int256 answer,,,) = _oracleAddress.latestRoundData();
    require(roundId != 0 && answer != 0, "Oracle returns incorrect data from latestRoundData()");

    croOracle = AggregatorV3Interface(_oracleAddress);
  }

  function registerOracle(address _tTokenAddress, AggregatorV3Interface _oracleAddress) external onlyOwner {

    require(_oracleAddress.decimals() != 0, "Oracle returns 0 decimals");
    (uint80 roundId, int256 answer,,,) = _oracleAddress.latestRoundData();
    require(roundId != 0 && answer != 0, "Oracle returns incorrect data from latestRoundData()");

    // Overwrite if already registered. No need to perform null-check;
    tokenOracle[_tTokenAddress] = _oracleAddress;
  }

  function unregisterOracle(address _tTokenAddress) external onlyOwner {
    tokenOracle[_tTokenAddress] = AggregatorV3Interface(address(0));
  }

  // dapp token standard decimal = 18
  function getNativeCurrencyPriceFeed() public view returns(uint) {
    assert(address(croOracle) != address(0));

    (,int256 answer,,,) = croOracle.latestRoundData();
    uint decimals = croOracle.decimals();

    return uint(answer).mul(10 ** (18 - decimals));
  }

  // dapp token standard decimal = 18
  function getTokenPriceFeed(address _token) public view returns(uint) {
    address token = _token;

    // always return 10**18 for stable coin
    if (isStableCoin[token]) {
      return 10 ** 18;
    }

    require(address(tokenOracle[address(token)]) != address(0), "Token is not registered in oracle");

    (,int256 answer,,,) = tokenOracle[token].latestRoundData();
    uint decimals = tokenOracle[token].decimals();

    return uint(answer).mul(10 ** (18 - decimals));
  }

  // short token with token collateral
  /// @notice user initiate short action
  /// @param _targetToken The address of the token user wants to short
  /// @param _targetAmount The amount of the target token
  /// @param _collateralToken The address of the collateral token
  function openShort(address _targetToken, uint _targetAmount, address _collateralToken) external {
    address targetToken = _targetToken;
    address collateralToken = _collateralToken;
    require(marketsMapping[targetToken] != address(0), "No market to short");
    require(validCollateral[collateralToken], "Not valid collateral");
    require(targetToken != collateralToken, "Target should be different than collateral");
    require(userBorrowed[msg.sender][collateralToken] == 0, "Already borrowed this collateral token");
    
    address tToken = marketsMapping[targetToken];
    address tCollateralToken = marketsMapping[collateralToken];
    uint targetAmount = _targetAmount;


    uint collateralAmount;
    // collateralTokenPrice * collateralAmount = targetTokenPrice * targetTokenAmount * 2
    // use block to avoid stack too deep
    {
      uint tokenPriceFeed = getTokenPriceFeed(targetToken);
      uint collateralPriceFeed = getTokenPriceFeed(collateralToken);

      uint raw = targetAmount.mul(tokenPriceFeed).mul(2).div(collateralPriceFeed);
      uint tokenDecimal = tokenDecimals[targetToken];
      uint collateralDecimal = tokenDecimals[collateralToken];
      collateralAmount = tokenDecimal > collateralDecimal ? raw.div(10 ** (tokenDecimal - collateralDecimal)) : raw.div(10 ** (collateralDecimal - tokenDecimal));
    }
    console.log("col Amount %d", collateralAmount);

    uint tCollateralAmount = _transferCollateralEnterMarket(collateralToken, tCollateralToken, collateralAmount);

    ShortOrder memory order;
    uint id = userNextShortId[msg.sender];
    order.id = id;
    order.targetToken = targetToken;
    order.collateralToken= collateralToken;
    order.collateralAmount = collateralAmount;
    order.tCollateralAmount = tCollateralAmount;

    // borrow
    (,, uint borrowedAmountBefore,) = TErc20Interface(tToken).getAccountSnapshot(address(this));
    TErc20Interface(tToken).borrow(targetAmount);
    (,, uint borrowedAmountAfter,) = TErc20Interface(tToken).getAccountSnapshot(address(this));
    order.targetAmount = borrowedAmountAfter.sub(borrowedAmountBefore);

    //--------- VVS operation ----------
    uint shortTokenAmount = _exchangeTokenForUSDC(targetToken, targetAmount);

    order.shortTokenAmount = shortTokenAmount;
    userShortOrders[msg.sender].push(order);
    userShortOrder[msg.sender][id] = order;
    userNextShortId[msg.sender]++;

    shortToken.mint(msg.sender, shortTokenAmount);    
    // emit();
    emit InitiateShort(msg.sender, targetToken, targetAmount, collateralToken);
  }

  function _transferCollateralEnterMarket(address _collateralToken, address _tCollateralToken, uint _collateralAmount) private returns (uint) {
    address collateralToken = _collateralToken;
    address tCollateralToken = _tCollateralToken;
    uint collateralAmount = _collateralAmount;

    // should approve contract to spend user's collateral beforehand or else fail
    IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

    // approve terc20 contract to spend contract erc20
    if (IERC20(collateralToken).allowance(address(this), tCollateralToken) < collateralAmount) {
      IERC20(collateralToken).safeApprove(tCollateralToken, type(uint).max);
    }

    // enter markets
    marketJoined.push(tCollateralToken);
    tectonic.enterMarkets(marketJoined);

    // mint tUSDC or tTUSD
    (, uint tCollateralTokenAmountBefore,,) = TErc20Interface(tCollateralToken).getAccountSnapshot(address(this));
    TErc20Interface(tCollateralToken).mint(collateralAmount);
    (,uint tCollateralTokenAmountAfter,,) = TErc20Interface(tCollateralToken).getAccountSnapshot(address(this));

    return tCollateralTokenAmountAfter.sub(tCollateralTokenAmountBefore);
  }

  // redeem
  // user should approve goju token for this contract in order to use this function
  /// @notice user redeem short action
  function redeemShort(uint orderId) external {
    ShortOrder storage order = userShortOrder[msg.sender][orderId];
    // signature?
    // uint id;
    // address targetToken;
    // address collateralToken;
    // uint targetAmount;
    // uint collateralAmount;
    // uint tCollateralAmount;
    // uint shortTokenAmount;
    // shortToken.transferFrom(msg.sender, address(this), order.shortTokenAmount);
    shortToken.burn(msg.sender, order.shortTokenAmount);

    address[] memory path = new address[](2);
    path[0] = USDC;
    path[1] = order.targetToken;

    if (IERC20(USDC).allowance(address(this), address(vvsRouter)) < order.shortTokenAmount) {
      IERC20(USDC).safeApprove(address(vvsRouter), type(uint).max);
    }

    {
    (, uint liqq, uint shortfalll) = tectonic.getHypotheticalAccountLiquidity(address(this), marketsMapping[order.collateralToken], order.tCollateralAmount, 0);
    console.log('dapp account liquidity and shortfall %d %d', liqq, shortfalll);
    }
    // ask if USDC is enough for borrowed amount
    uint[] memory amountResult = vvsRouter.getAmountsIn(order.targetAmount, path);
    //                                            usdc           weth
    console.log("getAmountsIn Result %d %d", amountResult[0], amountResult[1]);

    uint[] memory swapResult;
    uint leftUSDC;
    uint targetAmount;
    if (amountResult[0] > order.shortTokenAmount) { // need more USDC to exchange back the borrowed amount
      console.log("nee more");
      swapResult = vvsRouter.swapExactTokensForTokens(order.shortTokenAmount, 0, path, address(this), block.timestamp + 3 minutes);
      targetAmount = swapResult[swapResult.length-1];
      console.log("targetAmount %d", targetAmount);
    } else { // USDC enough to pay back borrowed amount
      console.log("enough");
      swapResult = vvsRouter.swapTokensForExactTokens(order.targetAmount, order.shortTokenAmount, path, address(this), block.timestamp + 3 minutes);
      leftUSDC = order.shortTokenAmount.sub(swapResult[0]);
      targetAmount = order.targetAmount;
    }
    // should approve
    if (IERC20(order.targetToken).allowance(address(this), marketsMapping[order.targetToken]) < targetAmount) {
      IERC20(order.targetToken).safeApprove(marketsMapping[order.targetToken], type(uint).max);
    }
    // pay back
    TErc20Interface(marketsMapping[order.targetToken]).repayBorrow(targetAmount);

    // get back max collateral
    (, uint liq, uint shortfall) = tectonic.getHypotheticalAccountLiquidity(address(this), marketsMapping[order.collateralToken], order.tCollateralAmount, 0);
    console.log('dapp account liquidity and shortfall %d %d', liq, shortfall);

    uint collateralBefore = IERC20(order.collateralToken).balanceOf(address(this));
    uint success = TErc20Interface(marketsMapping[order.collateralToken]).redeem(order.tCollateralAmount - shortfall.div(10**8));
    console.log('return redeem function %d', success);
    uint collateralAfter = IERC20(order.collateralToken).balanceOf(address(this));
    uint collateralPayBack = collateralAfter - collateralBefore;

    // transfer back left usdc token and collateral
    // short amount == usdc amount
    if (order.collateralToken == USDC) {
      IERC20(USDC).safeTransfer(msg.sender, leftUSDC.add(collateralPayBack));
    } else {
      IERC20(USDC).safeTransfer(msg.sender, leftUSDC);
      IERC20(order.collateralToken).safeTransfer(msg.sender, collateralPayBack);
    }
    // emit();
  }

  function _exchangeTokenForUSDC(address _targetToken, uint _targetAmount) private returns (uint) {
    address[] memory path = new address[](2);

    path[0] = _targetToken;
    path[1] = USDC;

    if (IERC20(_targetToken).allowance(address(this), address(vvsRouter)) < _targetAmount) {
      IERC20(_targetToken).safeApprove(address(vvsRouter), type(uint).max);
    }
    // amountOutMin? deadline?
    uint[] memory swapResult = vvsRouter.swapExactTokensForTokens(_targetAmount, 0, path, address(this), block.timestamp + 3 minutes);
    console.log("swapped USDC %d", swapResult[swapResult.length-1]);

    return swapResult[swapResult.length-1];
  }

  function _exchangeETHForUSDC() private returns (uint) {
    address[] memory path = new address[](2);
    address targetToken = WCRO;
    uint targetAmount = msg.value;

    path[0] = targetToken;
    path[1] = USDC;

    if (IERC20(targetToken).allowance(address(this), address(vvsRouter)) < targetAmount) {
      IERC20(targetToken).safeApprove(address(vvsRouter), type(uint).max);
    }
    // amountOutMin? deadline?
    uint[] memory swapResult = vvsRouter.swapExactETHForTokens(0, path, address(this), block.timestamp + 3 minutes);
    console.log("swapped USDC %d", swapResult[swapResult.length-1]);

    return swapResult[swapResult.length-1];
  }
}
