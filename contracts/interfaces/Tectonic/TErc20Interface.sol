pragma solidity >= 0.5.16;

interface TErc20Interface {

  /*** User Interface ***/

  function mint(uint mintAmount) external returns (uint);
  function redeem(uint redeemTokens) external returns (uint);
  function redeemUnderlying(uint redeemAmount) external returns (uint);
  function borrow(uint borrowAmount) external returns (uint);
  function repayBorrow(uint repayAmount) external returns (uint);
  function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);

  // function borrowBalanceStored(address account) external view returns (uint);
  function borrowBalanceCurrent(address account) external returns (uint);
  function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
}

