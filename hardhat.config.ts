import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    // only: [':ERC20$'],
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545/",
    },
    "cronos-mainnet": {
      url: "https://mainnet-archive.cronoslabs.com/v1/55e37d8975113ae7a44603ef8ce460aa",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    }
  },
};

export default config;
