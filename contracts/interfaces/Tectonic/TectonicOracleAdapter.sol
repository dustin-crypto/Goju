pragma solidity >= 0.5.16;

interface TectonicOracleAdapter {
  function getUnderlyingPrice(address tToken) external view returns (uint);
}
