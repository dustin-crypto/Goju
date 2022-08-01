import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, BigNumber, utils } from "ethers";
import { Jujutsu2 } from "../typechain-types/contracts/Jujutsu2";
import { Jujutsu2__factory } from "../typechain-types/factories/contracts/Jujutsu2__factory";
import { Goju__factory } from "../typechain-types/factories/contracts/token/Goju__factory";
import { Goju } from "../typechain-types";
import vvsRouterABI from "./abis/vvsRouter.json";
import wcroABI from "./abis/wcro.json";
import erc20ABI from "./abis/erc20.json";
import tErc20ABI from "./abis/tErc20.json";

const BIG_ZERO = BigNumber.from(0);
const BIG_ONE = BigNumber.from(1);
const BIG_10POW18 = ethers.constants.WeiPerEther;

describe("Dapp", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployDappFixture() {
    const VVSRouterAddress = "0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae";
    const TectonicProxyAddress = "0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0";
    // tokens
    const TUSD = "0x87EFB3ec1576Dec8ED47e58B832bEdCd86eE186e";
    const USDC = "0xc21223249CA28397B4B6541dfFaEcC539BfF0c59";

    const WBTC = "0x062E66477Faf219F25D27dCED647BF57C3107d52";
    const WETH = "0xe44Fd7fCb2b1581822D0c862B68222998a0c299a";
    const DAI = "0xF2001B145b43032AAF5Ee2884e456CCd805F677D";
    const USDT = "0x66e428c3f67a68878562e79A0234c1F83c208770";
    const TONIC = "0xDD73dEa10ABC2Bff99c60882EC5b2B81Bb1Dc5B2";

    const tokensAddr: string[] = [
      "0xc21223249CA28397B4B6541dfFaEcC539BfF0c59", // USDC
      "0x062E66477Faf219F25D27dCED647BF57C3107d52", // WBTC
      "0xe44Fd7fCb2b1581822D0c862B68222998a0c299a", // WETH
      "0xF2001B145b43032AAF5Ee2884e456CCd805F677D", // DAI
      "0x66e428c3f67a68878562e79A0234c1F83c208770", // USDT
      "0xDD73dEa10ABC2Bff99c60882EC5b2B81Bb1Dc5B2", // TONIC
      "0x87EFB3ec1576Dec8ED47e58B832bEdCd86eE186e", // TUSD
    ];
    const tokenDecimals = [6, 8, 18, 18, 6, 18, 18];

    const tUSDC = "0xB3bbf1bE947b245Aef26e3B6a9D777d7703F4c8e";
    const tWBTC = "0x67fD498E94d95972a4A2a44AccE00a000AF7Fe00";
    const tWETH = "0x543F4Db9BD26C9Eb6aD4DD1C33522c966C625774";
    const tDAI = "0xE1c4c56f772686909c28C319079D41adFD6ec89b";
    const tUSDT = "0xA683fdfD9286eeDfeA81CF6dA14703DA683c44E5";
    const tTONIC = "0xfe6934FDf050854749945921fAA83191Bccf20Ad";
    const tTUSD = "0x4bD41f188f6A05F02b46BB2a1f8ba776e528F9D2";
    const tCRO = "0xeAdf7c01DA7E93FdB5f16B0aa9ee85f978e89E95";

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

    // Contracts are deployed using the first signer/account by default
    const [owner, user1] = await ethers.getSigners();

    // deploy goju token (short token) for this dapp
    const Short: Goju__factory = await ethers.getContractFactory("Goju");
    const goju: Goju = await Short.deploy();
    await goju.deployed();

    const ExchangeLibrary = await ethers.getContractFactory("ExchangeLibrary");
    const exlib = await ExchangeLibrary.deploy();
    await exlib.deployed();

    // deploy dapp
    const Dapp: Jujutsu2__factory = await ethers.getContractFactory(
      "Jujutsu2",
      {
        libraries: {
          ExchangeLibrary: exlib.address,
        },
      }
    );
    const dapp: Jujutsu2 = await Dapp.deploy(
      goju.address,
      VVSRouterAddress,
      TectonicProxyAddress
    );
    await dapp.deployed();

    // set market token mapping in dapp
    let tx = await dapp.initialize(tokensAddr, tTokensAddr, tokenDecimals);
    await tx.wait();

    // transfer token owner to dapp contract
    tx = await goju.transferOwnership(dapp.address);
    await tx.wait();

    // set valid collateral
    tx = await dapp.setValidCollateral(TUSD);
    await tx.wait();
    tx = await dapp.setValidCollateral(USDC);
    await tx.wait();

    // set stable coin
    tx = await dapp.setStableCoin(TUSD);
    await tx.wait();
    tx = await dapp.setStableCoin(USDC);
    await tx.wait();

    const tokens = {
      WBTC,
      TUSD,
      USDC,
      WETH,
      DAI,
      USDT,
      TONIC,
      WCRO: "0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23",
    };
    const tTokens = { tWBTC, tTUSD, tUSDC, tWETH, tDAI, tUSDT, tTONIC, tCRO };
    return {
      dapp,
      goju,
      tokensAddr,
      tTokensAddr,
      owner,
      user1,
      tokens,
      tTokens,
      VVSRouterAddress,
      TectonicProxyAddress,
    };
  }

  describe("Deployment", () => {
    it("Should set the right owner", async () => {
      const { dapp, owner } = await loadFixture(deployDappFixture);

      expect(await dapp.owner()).to.equal(owner.address);
    });

    it("Should set the right marketsMapping", async () => {
      const { dapp, tokensAddr, tTokensAddr } = await loadFixture(
        deployDappFixture
      );

      for (let i = 0; i < tokensAddr.length; i++) {
        expect(await dapp.marketsMapping(tokensAddr[i])).to.equal(
          tTokensAddr[i]
        );
      }
    });

    it("Should set Goju token owner to dapp", async () => {
      const { dapp, goju } = await loadFixture(deployDappFixture);

      expect(await goju.owner()).to.equal(dapp.address);
    });

    it("Should set TUSD and USDC to stable coin", async () => {
      const { dapp, tokens } = await loadFixture(deployDappFixture);

      expect(await dapp.isStableCoin(tokens.TUSD)).to.equal(true);
      expect(await dapp.isStableCoin(tokens.USDC)).to.equal(true);
    });

    it("Should set all tokens decimals", async () => {
      const { dapp, tokens } = await loadFixture(deployDappFixture);

      expect(await dapp.tokenDecimals(tokens.TUSD)).to.equal(18);
      expect(await dapp.tokenDecimals(tokens.WBTC)).to.equal(8);
      expect(await dapp.tokenDecimals(tokens.USDC)).to.equal(6);
      expect(await dapp.tokenDecimals(tokens.USDT)).to.equal(6);
      expect(await dapp.tokenDecimals(tokens.WETH)).to.equal(18);
      expect(await dapp.tokenDecimals(tokens.TONIC)).to.equal(18);
      expect(await dapp.tokenDecimals(tokens.DAI)).to.equal(18);
    });
  });

  describe("Transactions", () => {
    /* 1. Setup user USDC balance for collateral by exchanging in VVS
     * 2. Approve dapp to spend user's USDC
     */
    async function setupUserBalanceFixture() {
      const deployed = await loadFixture(deployDappFixture);
      const { dapp, user1, tokens, VVSRouterAddress } = deployed;
      const wcro: Contract = new ethers.Contract(
        "0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23",
        wcroABI,
        user1
      );
      const vvsRouter: Contract = new ethers.Contract(
        VVSRouterAddress,
        vvsRouterABI,
        user1
      );

      // Swap get USDC
      const blockNumber = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNumber);
      let tx = await vvsRouter
        .connect(user1)
        .swapExactETHForTokens(
          0,
          [wcro.address, tokens.USDC],
          user1.address,
          block.timestamp + 1000000,
          { value: utils.parseEther("4000") }
        );
      await tx.wait();

      // approve dapp to use USDC collateral
      const USDCContract: Contract = new ethers.Contract(
        tokens.USDC,
        erc20ABI,
        user1
      );
      tx = await USDCContract.connect(user1).approve(
        dapp.address,
        ethers.constants.MaxUint256
      );
      await tx.wait();

      return { ...deployed, USDCContract };
    }

    it("Should get user USDC as collateral by swapping in VVS", async () => {
      const { user1, tokens } = await loadFixture(setupUserBalanceFixture);
      const USDCContract: Contract = new ethers.Contract(
        tokens.USDC,
        erc20ABI,
        user1
      );
      const userUSDCBalance = await USDCContract.balanceOf(user1.address);
      console.log({ userUSDCBalance });
      expect(userUSDCBalance.gt(BIG_ZERO)).to.be.true;
    });

    it("Should user open short and get short token", async () => {
      const { dapp, goju, user1, tokens, tTokens, USDCContract } =
        await loadFixture(setupUserBalanceFixture);

      console.log("----------- before open short");
      console.log(
        "Monitor: user1 USDC balance",
        await USDCContract.balanceOf(user1.address)
      );
      console.log("-----------");

      // call openShort on dapp
      let tx = await dapp
        .connect(user1)
        .openShort(tokens.WETH, utils.parseEther("0.01"), tokens.USDC);
      await tx.wait();

      console.log("----------- after open short");
      console.log(
        "Monitor: user1 USDC balance",
        await USDCContract.balanceOf(user1.address)
      );
      console.log("-----------\n");

      expect(await dapp.userNextShortId(user1.address)).to.equal(BIG_ONE);
      const shortOrder = await dapp.userShortOrders(user1.address, 0);

      console.log("----------- user open order\n");
      console.log("order", shortOrder);
      console.log("-----------\n");

      expect(shortOrder.targetToken).to.equal(tokens.WETH);
      expect(shortOrder.collateralToken).to.equal(tokens.USDC);
      expect(shortOrder.targetAmount).to.equal(utils.parseEther("0.01"));

      // ensure borrowed token is exchanged to USDC from VVS
      const WETHContract: Contract = new ethers.Contract(
        tokens.WETH,
        erc20ABI,
        user1
      );
      const wethInDapp = await WETHContract.balanceOf(dapp.address);
      console.log("WETH in dapp", wethInDapp);
      expect(wethInDapp).to.equal(BIG_ZERO);

      // ensure dapp holds tCollateral and exchanged USDC
      const tUSDCContract: Contract = new ethers.Contract(
        tTokens.tUSDC,
        tErc20ABI,
        user1
      );
      const tTokenInDapp = await tUSDCContract.balanceOf(dapp.address);
      const usdcInDapp = await USDCContract.balanceOf(dapp.address);
      console.log("tUSDC in dapp", tTokenInDapp);
      console.log("USDC in dapp", usdcInDapp);
      expect(tTokenInDapp.gt(BIG_ZERO)).to.be.true;
      expect(usdcInDapp.gt(BIG_ZERO)).to.be.true;

      expect((await goju.balanceOf(user1.address)).gt(BIG_ZERO)).to.be.true;
      console.log("user1 Goju balance", await goju.balanceOf(user1.address));
    });

    it("Should user open short and redeem", async () => {
      const { dapp, goju, user1, tokens, tTokens, USDCContract } =
        await loadFixture(setupUserBalanceFixture);
      // call openShort on dapp
      let tx = await dapp
        .connect(user1)
        .openShort(tokens.WETH, utils.parseEther("0.01"), tokens.USDC);
      await tx.wait();

      // approve dapp to use user's goju token
      tx = await goju
        .connect(user1)
        .approve(dapp.address, ethers.constants.MaxUint256);
      await tx.wait();

      console.log("----------- before redeem short");
      console.log(
        "Monitor: user1 USDC balance",
        await USDCContract.balanceOf(user1.address)
      );
      console.log("-----------");

      tx = await dapp.connect(user1).redeemShort(0);
      await tx.wait();

      console.log("----------- after redeem short");
      console.log(
        "Monitor: user1 USDC balance",
        await USDCContract.balanceOf(user1.address)
      );

      const WETHContract: Contract = new ethers.Contract(
        tokens.WETH,
        erc20ABI,
        user1
      );
      const wethInDapp = await WETHContract.balanceOf(dapp.address);
      console.log("Dapp WETH", wethInDapp);
      const tUSDCContract: Contract = new ethers.Contract(
        tTokens.tUSDC,
        tErc20ABI,
        user1
      );
      const tTokenInDapp = await tUSDCContract.balanceOf(dapp.address);
      const usdcInDapp = await USDCContract.balanceOf(dapp.address);
      console.log("Dapp tUSDC", tTokenInDapp);
      console.log("Dapp USDC", usdcInDapp);
      console.log("-----------");
      expect((await goju.balanceOf(user1.address)).eq(BIG_ZERO)).to.be.true;
    });
  });
});
