import { ethers } from "hardhat";
import { Jujutsu2 } from "../typechain-types/contracts/Jujutsu2";
import { Jujutsu2__factory } from "../typechain-types/factories/contracts/Jujutsu2__factory";
import { Goju__factory } from "../typechain-types/factories/contracts/token/Goju__factory";
import { Goju } from "../typechain-types";

let dapp: Jujutsu2;
let goju: Goju;

const deploy = async () => {
  const VVSRouterAddress = "0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae";
  const TectonicProxyAddress = "0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0";
  const [deployer] = await ethers.getSigners();

  console.log("--------------------- Deployer Info ----------------------\n");
  console.log("Deploying contracts with the account:", deployer.address);

  const weiAmount = (await deployer.getBalance()).toString();

  console.log("Account balance:", ethers.utils.formatEther(weiAmount));

  console.log("\n----------------------------------------------------------\n");

  console.log("--------------------- Deploying Goju token contract ----------------------\n");
  const Short: Goju__factory = await ethers.getContractFactory("Goju");
  goju = await Short.deploy();
  await goju.deployed();
  console.log(`✅ Done - Goju token address: ${goju.address}\n`);

  console.log("--------------------- Deploying ExchangeLibrary ----------------------\n");
  const ExchangeLibrary = await ethers.getContractFactory("ExchangeLibrary");
  const exlib = await ExchangeLibrary.deploy();
  await exlib.deployed();
  console.log(`✅ Done - ExchangeLibrary address: ${exlib.address}\n`);

  console.log("--------------------- Deploying Dapp contract ----------------------\n");
  const Dapp: Jujutsu2__factory = await ethers.getContractFactory("Jujutsu2", {
    libraries: {
      "ExchangeLibrary": exlib.address,
    }
  });
  dapp = await Dapp.deploy(goju.address, VVSRouterAddress, TectonicProxyAddress);
  await dapp.deployed();
  console.log(`✅ Done - Dapp address: ${dapp.address}\n`);
}

const initialize = async () => {
  const TUSD = "0x87EFB3ec1576Dec8ED47e58B832bEdCd86eE186e";
  const USDC = "0xc21223249CA28397B4B6541dfFaEcC539BfF0c59";

  const tokensAddr: string[] = [
    "0xc21223249CA28397B4B6541dfFaEcC539BfF0c59", // USDC
    "0x062E66477Faf219F25D27dCED647BF57C3107d52", // WBTC
    "0xe44Fd7fCb2b1581822D0c862B68222998a0c299a", // WETH
    "0xF2001B145b43032AAF5Ee2884e456CCd805F677D", // DAI
    "0x66e428c3f67a68878562e79A0234c1F83c208770", // USDT
    "0xDD73dEa10ABC2Bff99c60882EC5b2B81Bb1Dc5B2", // TONIC
    "0x87EFB3ec1576Dec8ED47e58B832bEdCd86eE186e", // TUSD
  ];
  const tTokensAddr: string[] = [
    "0xB3bbf1bE947b245Aef26e3B6a9D777d7703F4c8e", // tUSDC
    "0x67fD498E94d95972a4A2a44AccE00a000AF7Fe00", // tWBTC
    "0x543F4Db9BD26C9Eb6aD4DD1C33522c966C625774", // tWETH
    "0xE1c4c56f772686909c28C319079D41adFD6ec89b", // tDAI
    "0xA683fdfD9286eeDfeA81CF6dA14703DA683c44E5", // tUSDT
    "0xfe6934FDf050854749945921fAA83191Bccf20Ad", // tTONIC
    "0x4bD41f188f6A05F02b46BB2a1f8ba776e528F9D2", // tTUSD
    // "0xeAdf7c01DA7E93FdB5f16B0aa9ee85f978e89E95", // tCRO
  ];

  const tokenDecimals = [6, 8, 18, 18, 6, 18, 18];

  console.log("-------------------- Initialize Dapp contract ----------------------\n");
  // set market token mapping in dapp
  let tx = await dapp.initialize(tokensAddr, tTokensAddr, tokenDecimals);
  await tx.wait();

  console.log(`✅ Done\n`);

  console.log("------ Transfer Goju token contract owner to dapp contract ---------\n");
  tx = await goju.transferOwnership(dapp.address);
  await tx.wait();

  console.log(`✅ Done\n`);

  console.log("------------- Set valid collateral: TUSD, USDC ---------------------\n");
  tx = await dapp.setValidCollateral(TUSD);
  await tx.wait();
  tx = await dapp.setValidCollateral(USDC);
  await tx.wait();

  console.log(`✅ Done\n`);

  console.log("------------- Set stable coin: TUSD, USDC ---------------------------\n");
  tx = await dapp.setStableCoin(TUSD);
  await tx.wait();
  tx = await dapp.setStableCoin(USDC);
  await tx.wait();

  console.log(`✅ Done\n`);
}
async function main() {
  await deploy();
  await initialize();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
