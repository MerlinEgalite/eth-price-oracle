pragma solidity >=0.4.22 <0.8.0;

interface EthPriceOracleInterface {
  function getLatestEthPrice() external returns (uint256);
}
