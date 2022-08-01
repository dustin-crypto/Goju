pragma solidity >= 0.5.16;

interface TectonicCoreInterface {
  function getHypotheticalAccountLiquidity(
        address account,
        address tTokenModify,
        uint redeemTokens,
        uint borrowAmount) external view returns (uint, uint, uint);
    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata tTokens) external returns (uint[] memory);
    function exitMarket(address tToken) external returns (uint);

    /*** Policy Hooks ***/

    function mintAllowed(address tToken, address minter, uint mintAmount) external returns (uint);
    function mintVerify(address tToken, address minter, uint mintAmount, uint mintTokens) external;

    function redeemAllowed(address tToken, address redeemer, uint redeemTokens) external returns (uint);
    function redeemVerify(address tToken, address redeemer, uint redeemAmount, uint redeemTokens) external;

    function borrowAllowed(address tToken, address borrower, uint borrowAmount) external returns (uint);
    function borrowVerify(address tToken, address borrower, uint borrowAmount) external;

    function repayBorrowAllowed(
        address tToken,
        address payer,
        address borrower,
        uint repayAmount) external returns (uint);
    function repayBorrowVerify(
        address tToken,
        address payer,
        address borrower,
        uint repayAmount,
        uint borrowerIndex) external;

    function liquidateBorrowAllowed(
        address tTokenBorrowed,
        address tTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount) external returns (uint);
    function liquidateBorrowVerify(
        address tTokenBorrowed,
        address tTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount,
        uint seizeTokens) external;

    function seizeAllowed(
        address tTokenCollateral,
        address tTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) external returns (uint);
    function seizeVerify(
        address tTokenCollateral,
        address tTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) external;

    function transferAllowed(address tToken, address src, address dst, uint transferTokens) external returns (uint);
    function transferVerify(address tToken, address src, address dst, uint transferTokens) external;

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address tTokenBorrowed,
        address tTokenCollateral,
        uint repayAmount) external view returns (uint, uint);
}
