pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/VVS/IVVSRouter02.sol";
import "./interfaces/Tectonic/TEtherInterface.sol"; 
import "./interfaces/Tectonic/TErc20Interface.sol"; 
import "./interfaces/Tectonic/TectonicCoreInterface.sol"; 
import "./interfaces/Tectonic/TectonicOracleAdapter.sol"; 
import "./libraries/ExchangeLibrary.sol";
import "./token/Goju.sol";

contract Jujutsu2 is Ownable {
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
  event RedeemShort(address indexed user, uint orderId, uint USDCamount, uint TUSDamount);

  mapping(address => ShortOrder[]) public userShortOrders;
  mapping(address => mapping(uint => ShortOrder)) public userShortOrder;
  mapping(address => uint) public userNextShortId;

  address private constant USDC = 0xc21223249CA28397B4B6541dfFaEcC539BfF0c59;
  address private constant WCRO = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23;
  address private constant oracleAddress = 0xD360D8cABc1b2e56eCf348BFF00D2Bd9F658754A;
  address private constant tEther = 0xeAdf7c01DA7E93FdB5f16B0aa9ee85f978e89E95;

  address[] public marketJoined;
  mapping(address => address) public marketsMapping;
  mapping(address => bool) public validCollateral;
  mapping(address => uint) public tokenDecimals;
  mapping(address => bool) public isStableCoin;
  mapping(address => mapping(address => uint)) public userBorrowed; // [user][token]

  Goju public immutable shortToken;
  IVVSRouter02 vvsRouter;
  TectonicCoreInterface tectonic;
  TectonicOracleAdapter oracle;
  

  constructor (address _shortToken, address _vvs, address _tectonic) {
    shortToken = Goju(_shortToken);
    vvsRouter = IVVSRouter02(_vvs);
    tectonic = TectonicCoreInterface(_tectonic);
    oracle = TectonicOracleAdapter(oracleAddress);
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
      uint tokenPriceFeed = oracle.getUnderlyingPrice(marketsMapping[targetToken]);
      uint collateralPriceFeed = oracle.getUnderlyingPrice(tCollateralToken);

      collateralAmount = targetAmount.mul(tokenPriceFeed).mul(2).div(collateralPriceFeed);
    }

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
    uint shortTokenAmount = ExchangeLibrary.exchangeTokenForUSDC(targetToken, targetAmount);

    order.shortTokenAmount = shortTokenAmount;
    userShortOrders[msg.sender].push(order);
    userShortOrder[msg.sender][id] = order;
    userNextShortId[msg.sender]++;

    shortToken.mint(msg.sender, shortTokenAmount);    
    emit InitiateShort(msg.sender, targetToken, targetAmount, collateralToken);
  }

  function _transferCollateralEnterMarket(address _collateralToken, address _tCollateralToken, uint _collateralAmount) private returns (uint) {
    // should approve contract to spend user's collateral beforehand or else fail
    IERC20(_collateralToken).safeTransferFrom(msg.sender, address(this), _collateralAmount);

    // approve terc20 contract to spend contract erc20
    if (IERC20(_collateralToken).allowance(address(this), _tCollateralToken) < _collateralAmount) {
      IERC20(_collateralToken).safeApprove(_tCollateralToken, type(uint).max);
    }

    // enter markets
    marketJoined.push(_tCollateralToken);
    tectonic.enterMarkets(marketJoined);

    // mint tUSDC or tTUSD
    (, uint tCollateralTokenAmountBefore,,) = TErc20Interface(_tCollateralToken).getAccountSnapshot(address(this));
    TErc20Interface(_tCollateralToken).mint(_collateralAmount);
    (,uint tCollateralTokenAmountAfter,,) = TErc20Interface(_tCollateralToken).getAccountSnapshot(address(this));

    return tCollateralTokenAmountAfter.sub(tCollateralTokenAmountBefore);
  }

  // short CRO with token collateral
  function openEthShort(address _collateralToken) payable external {
    address collateralToken = _collateralToken;
    require(msg.value > 0, "Not valid amount");
    require(validCollateral[collateralToken], "Not valid collateral");

    address tCollateralToken = marketsMapping[collateralToken];

    uint targetAmount = uint(msg.value);
    uint collateralAmount;
    // collateralTokenPrice * collateralAmount = targetTokenPrice * targetTokenAmount * 2
    // use block to avoid stack too deep
    {
      uint tokenPriceFeed = oracle.getUnderlyingPrice(tEther);
      uint collateralPriceFeed = oracle.getUnderlyingPrice(tCollateralToken);

      collateralAmount = targetAmount.mul(tokenPriceFeed).mul(2).div(collateralPriceFeed);
    }

    uint tCollateralAmount = _transferCollateralEnterMarket(collateralToken, tCollateralToken, collateralAmount);

    ShortOrder memory order;
    uint id = userNextShortId[msg.sender];
    order.id = id;
    order.targetToken = WCRO;
    order.collateralToken= collateralToken;
    order.collateralAmount = collateralAmount;
    order.tCollateralAmount = tCollateralAmount;

    // borrow
    (,, uint borrowedAmountBefore,) = TEtherInterface(tEther).getAccountSnapshot(address(this));
    TErc20Interface(tEther).borrow(targetAmount);
    (,, uint borrowedAmountAfter,) = TEtherInterface(tEther).getAccountSnapshot(address(this));
    order.targetAmount = borrowedAmountAfter.sub(borrowedAmountBefore);

    // VVS operation
    uint shortTokenAmount = ExchangeLibrary.exchangeETHForUSDC();

    order.shortTokenAmount = shortTokenAmount;
    userShortOrders[msg.sender].push(order);
    userShortOrder[msg.sender][id] = order;
    userNextShortId[msg.sender]++;

    shortToken.mint(msg.sender, shortTokenAmount);  
    emit InitiateShort(msg.sender, WCRO, targetAmount, collateralToken);
  }

  // redeem
  /// @notice user redeem short action
  /// @notice user should approve goju token for this contract in order to use this function
  function redeemShort(uint orderId) external {
    ShortOrder storage order = userShortOrder[msg.sender][orderId];
    shortToken.burn(msg.sender, order.shortTokenAmount);

    address[] memory path = new address[](2);
    path[0] = USDC;
    path[1] = order.targetToken;

    if (IERC20(USDC).allowance(address(this), address(vvsRouter)) < order.shortTokenAmount) {
      IERC20(USDC).safeApprove(address(vvsRouter), type(uint).max);
    }

    // ask if USDC is enough for borrowed amount
    uint[] memory amountResult = vvsRouter.getAmountsIn(order.targetAmount, path);

    uint[] memory swapResult;
    uint leftUSDC;
    uint targetAmount;
    if (amountResult[0] > order.shortTokenAmount) { // need more USDC to exchange back the borrowed amount
      swapResult = vvsRouter.swapExactTokensForTokens(order.shortTokenAmount, 0, path, address(this), block.timestamp + 3 minutes);
      targetAmount = swapResult[swapResult.length-1];
    } else { // USDC enough to pay back borrowed amount
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
    (,, uint shortfall) = tectonic.getHypotheticalAccountLiquidity(address(this), marketsMapping[order.collateralToken], order.tCollateralAmount, 0);

    uint collateralBefore = IERC20(order.collateralToken).balanceOf(address(this));
    TErc20Interface(marketsMapping[order.collateralToken]).redeem(order.tCollateralAmount - shortfall.div(10**8));
    uint collateralAfter = IERC20(order.collateralToken).balanceOf(address(this));
    uint collateralPayBack = collateralAfter - collateralBefore;

    // transfer back left usdc token and collateral
    // short amount == usdc amount
    if (order.collateralToken == USDC) {
      IERC20(USDC).safeTransfer(msg.sender, leftUSDC.add(collateralPayBack));
      emit RedeemShort(msg.sender, orderId, leftUSDC.add(collateralPayBack), 0);
    } else {
      IERC20(USDC).safeTransfer(msg.sender, leftUSDC);
      IERC20(order.collateralToken).safeTransfer(msg.sender, collateralPayBack);
      emit RedeemShort(msg.sender, orderId, leftUSDC, collateralPayBack);
    }
  }

  function redeemETHShort(uint orderId) external {
    ShortOrder storage order = userShortOrder[msg.sender][orderId];
    shortToken.burn(msg.sender, order.shortTokenAmount);

    address[] memory path = new address[](2);
    path[0] = USDC;
    path[1] = order.targetToken;

    if (IERC20(USDC).allowance(address(this), address(vvsRouter)) < order.shortTokenAmount) {
      IERC20(USDC).safeApprove(address(vvsRouter), type(uint).max);
    }

    // ask if USDC is enough for borrowed amount
    uint[] memory amountResult = vvsRouter.getAmountsIn(order.targetAmount, path);

    uint[] memory swapResult;
    uint leftUSDC;
    uint targetAmount;
    if (amountResult[0] > order.shortTokenAmount) { // need more USDC to exchange back the borrowed amount
      swapResult = vvsRouter.swapExactTokensForETH(order.shortTokenAmount, 0, path, address(this), block.timestamp + 3 minutes);
      targetAmount = swapResult[swapResult.length-1];
    } else { // USDC enough to pay back borrowed amount
      swapResult = vvsRouter.swapTokensForExactETH(order.targetAmount, order.shortTokenAmount, path, address(this), block.timestamp + 3 minutes);
      leftUSDC = order.shortTokenAmount.sub(swapResult[0]);
      targetAmount = order.targetAmount;
    }

    // pay back
    TEtherInterface(tEther).repayBorrow{ value: targetAmount }();

    // get back max collateral
    (,, uint shortfall) = tectonic.getHypotheticalAccountLiquidity(address(this), marketsMapping[order.collateralToken], order.tCollateralAmount, 0);

    uint collateralBefore = IERC20(order.collateralToken).balanceOf(address(this));
    TErc20Interface(marketsMapping[order.collateralToken]).redeem(order.tCollateralAmount - shortfall.div(10**8));
    uint collateralAfter = IERC20(order.collateralToken).balanceOf(address(this));
    uint collateralPayBack = collateralAfter - collateralBefore;

    // transfer back left usdc token and collateral
    // short amount == usdc amount
    if (order.collateralToken == USDC) {
      IERC20(USDC).safeTransfer(msg.sender, leftUSDC.add(collateralPayBack));
      emit RedeemShort(msg.sender, orderId, leftUSDC.add(collateralPayBack), 0);
    } else {
      IERC20(USDC).safeTransfer(msg.sender, leftUSDC);
      IERC20(order.collateralToken).safeTransfer(msg.sender, collateralPayBack);
      emit RedeemShort(msg.sender, orderId, leftUSDC, collateralPayBack);
    }
  }
}
