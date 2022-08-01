import { ethers } from "hardhat";
import { Jujutsu2 } from "../typechain-types/contracts/Jujutsu2";
import vvsRouterABI from "../test/abis/vvsRouter.json";
import { Contract, utils } from "ethers";
import erc20ABI from "../test/abis/erc20.json";

let dapp: Jujutsu2;
const USDC = "0xc21223249CA28397B4B6541dfFaEcC539BfF0c59";
const WETH = "0xe44Fd7fCb2b1581822D0c862B68222998a0c299a";
const dappAddress: string = process.env.dapp!;
const libAddress: string = process.env.lib!;

const buyUSDC = async () => {

  const [, user1] = await ethers.getSigners();
  const WCRO = "0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23";
  const VVSRouterAddress = "0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae";
  const vvsRouter: Contract = new ethers.Contract(VVSRouterAddress, vvsRouterABI, user1);

  // Swap get USDC
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  let tx = await vvsRouter.connect(user1).swapExactETHForTokens(0, [WCRO, USDC], user1.address, block.timestamp + 1000000, { value: utils.parseEther("100") });
  await tx.wait();

  // approve dapp to use USDC collateral
  const USDCContract: Contract = new ethers.Contract(USDC, erc20ABI, user1);
  tx = await USDCContract.connect(user1).approve(dappAddress, ethers.constants.MaxUint256);
  await tx.wait();

  console.log("--------------------- Swap Info ----------------------\n");

  console.log("user USDC balance", await USDCContract.balanceOf(user1.address));

  console.log(`✅ Done\n`);
}

const openShort = async () => {
  const [, user1] = await ethers.getSigners();


  console.log("------------- OPEN SHORT on WETH with USDC as collateral --------------\n");

  dapp = (await ethers.getContractFactory("Jujutsu2", {
    libraries: {
      "ExchangeLibrary": libAddress,
    }
  })).attach(dappAddress);

  let tx = await dapp.connect(user1).openShort(WETH, utils.parseEther("0.0001"), USDC);
  await tx.wait();

  console.log(`✅ Done\n`);
}
async function main() {
  if (!dappAddress || !libAddress) {
    throw new Error("Should provide dapp and lib address");
  }
  await buyUSDC();
  await openShort();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
