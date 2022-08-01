pragma solidity >= 0.5.16;

interface TEtherInterface {

  /*** User Interface ***/

  function mint() external payable;
  function redeem(uint redeemTokens) external returns (uint);
  function redeemUnderlying(uint redeemAmount) external returns (uint);
  function borrow(uint borrowAmount) external returns (uint);
  function repayBorrow() external payable;
  function repayBorrowBehalf(address borrower) external payable;

  // function borrowBalanceStored(address account) external view returns (uint);
  // function borrowBalanceCurrent(address account) external returns (uint);
  function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
}
