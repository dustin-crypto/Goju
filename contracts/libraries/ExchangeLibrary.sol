pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/VVS/IVVSRouter02.sol";

library ExchangeLibrary {
  using SafeERC20 for IERC20;

  function exchangeTokenForUSDC(address _targetToken, uint _targetAmount) external returns (uint) {
    address[] memory path = new address[](2);

    path[0] = _targetToken;
    path[1] = 0xc21223249CA28397B4B6541dfFaEcC539BfF0c59;
    IVVSRouter02 vvsRouter = IVVSRouter02(0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae);
    if (IERC20(_targetToken).allowance(address(this), address(vvsRouter)) < _targetAmount) {
      IERC20(_targetToken).safeApprove(address(vvsRouter), type(uint).max);
    }
    // amountOutMin? deadline?
    uint[] memory swapResult = vvsRouter.swapExactTokensForTokens(_targetAmount, 0, path, address(this), block.timestamp + 3 minutes);

    return swapResult[swapResult.length-1];
  }

  function exchangeETHForUSDC() external returns (uint) {
    address[] memory path = new address[](2);
    path[0] = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23; // WCRO
    path[1] = 0xc21223249CA28397B4B6541dfFaEcC539BfF0c59; // USDC

    // amountOutMin? deadline?
    IVVSRouter02 vvsRouter = IVVSRouter02(0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae);
    uint[] memory swapResult = vvsRouter.swapExactETHForTokens{value: msg.value }(0, path, address(this), block.timestamp + 3 minutes);

    return swapResult[swapResult.length-1];
  }
}
