import { ethers } from "hardhat";
import { Jujutsu2 } from "../typechain-types/contracts/Jujutsu2";
import { Contract, utils } from "ethers";
import erc20ABI from "../test/abis/erc20.json";

let dapp: Jujutsu2;
const USDC = "0xc21223249CA28397B4B6541dfFaEcC539BfF0c59";
const dappAddress: string = process.env.dapp!;
const libAddress: string = process.env.lib!;

const redeemShort = async () => {
  const [, user1] = await ethers.getSigners();
  const USDCContract: Contract = new ethers.Contract(USDC, erc20ABI, user1);

  console.log("------------- Before Redeem order --------------\n");

  let balance = await USDCContract.balanceOf(user1.address);
  console.log('user USDC balance', balance.toString());

  console.log("------------- Redeem order --------------\n");

  dapp = (await ethers.getContractFactory("Jujutsu2", {
    libraries: {
      "ExchangeLibrary": libAddress,
    }
  })).attach(dappAddress);

  let tx = await dapp.connect(user1).redeemShort(0);
  await tx.wait();

  console.log("------------- After Redeem order --------------\n");

  console.log('user USDC balance', await USDCContract.balanceOf(user1.address));

  console.log(`✅ Done\n`);
}
async function main() {
  if (!dappAddress || !libAddress) {
    throw new Error("Should provide dapp and lib address");
  }
  await redeemShort();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
