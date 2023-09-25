require("@openzeppelin/hardhat-upgrades");

const { ethers, upgrades, network } = require("hardhat");
const { constants } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");
const { BigNumber, providers } = require("ethers");
const expectEvent = require("@openzeppelin/test-helpers/src/expectEvent");
const testHelpers = require("@openzeppelin/test-helpers");

describe("Blue Diamond Liquidity", () => {
  let admin,
    add1,
    add2,
    usdt,
    router,
    BDT,
    bdt,
    BlueDiamondLiquidity,
    blueDiamondLiquidity;

  BDT_PRICE_ORACLE = testHelpers.constants.ZERO_ADDRESS;
  USDT_PRICE_ORACLE = "0xEca2605f0BCF2BA5966372C99837b1F182d3D620";
  router = "0xEca2605f0BCF2BA5966372C99837b1F182d3D620";
  usdt = "0xEca2605f0BCF2BA5966372C99837b1F182d3D620";

  // function for converting to days
  function getDays(day) {
    let dayInSecond = day * 24 * 60 * 60;

    return dayInSecond;
  }

  function getAmount(amount) {
    let value = BigNumber.from(amount).mul(
      BigNumber.from(10).pow(BigNumber.from(18))
    );

    return value;
  }

  beforeEach(async () => {
    [admin, add1, add2, feeSetter] = await ethers.getSigners();

    // deploy BDT token contract
    BDT = await ethers.getContractFactory("BlueDiamondToken");
    bdt = await upgrades.deployProxy(BDT, {
      initializer: "initialize",
    });
    bdt.deployed();

    // deploy blue diamond liquidity contract
    BlueDiamondLiquidity = await ethers.getContractFactory(
      "BlueDiamondTokenLiquidity"
    );
    blueDiamondLiquidity = await upgrades.deployProxy(
      BlueDiamondLiquidity,
      [usdt, bdt.address, router, USDT_PRICE_ORACLE],
      { initializer: "initialize" }
    );
    blueDiamondLiquidity.deployed();
  });

  describe("Initialize Liquidity", () => {
    it("Should set the owners properly", async () => {
      expect(await blueDiamondLiquidity.owner()).to.equal(admin.address);
    });

    it("Should set all the initial variables", async () => {
      result = await blueDiamondLiquidity.slippageRate();
      expect(result).to.equal(50);

      result = await blueDiamondLiquidity.oracleAddresses();
      expect(result[0]).to.equal(USDT_PRICE_ORACLE);
      expect(result[1]).to.equal(BDT_PRICE_ORACLE);

      result = await blueDiamondLiquidity.tokenAddresses();
      expect(result[0]).to.equal(usdt);
      expect(result[1]).to.equal(bdt.address);

      result = await blueDiamondLiquidity.routerAddress();
      expect(result).to.equal(router);
    });
  });

  describe("Modify Slippage Rate", () => {
    it("Should revert if the caller is not owner", async () => {
      let rate = 500; // 5%
      await expect(
        blueDiamondLiquidity.connect(add1).modifySlippageRate(rate)
      ).to.be.revertedWith("NotOwner");
    });

    it("Should revert if the rate is invalid", async () => {
      let rate = 0;

      await expect(
        blueDiamondLiquidity.connect(admin).modifySlippageRate(rate)
      ).to.be.revertedWith("InvalidRate");

      rate = 11000; // rate 110%

      await expect(
        blueDiamondLiquidity.connect(admin).modifySlippageRate(rate)
      ).to.be.revertedWith("InvalidRate");
    });

    it("Should modify the slippage rate successfully", async () => {
      let rate = 500;

      let result = await blueDiamondLiquidity.modifySlippageRate(rate);

      expectEvent.inTransaction(
        result.tx,
        blueDiamondLiquidity,
        "SlippageRateModified",
        { newSlippageRate: 500 }
      );

      expect(await blueDiamondLiquidity.slippageRate()).to.equal(500);
    });
  });

  describe("Modify Oracle Addresses", () => {
    it("Should revert if the caller is not owner", async () => {
      let newOracleBDT = "0xa8357bf572460fc40f4b0acacbb2a6a61c89f475"; // AAVE

      await expect(
        blueDiamondLiquidity
          .connect(add1)
          .modifyOracleAddresses(USDT_PRICE_ORACLE, newOracleBDT)
      ).to.be.revertedWith("NotOwner");
    });

    it("Should revert if the oracle addresses are zero address", async () => {
      let newOracleBDT = constants.ZERO_ADDRESS; // zero address

      await expect(
        blueDiamondLiquidity
          .connect(admin)
          .modifyOracleAddresses(USDT_PRICE_ORACLE, newOracleBDT)
      ).to.be.revertedWith("ZeroAddress");
    });

    it("Should modify the oracle addresses successfully", async () => {
      let newOracleBDT = "0xA8357BF572460fC40f4B0aCacbB2a6A61c89f475"; // AAVE

      let result = await blueDiamondLiquidity
        .connect(admin)
        .modifyOracleAddresses(USDT_PRICE_ORACLE, newOracleBDT);

      expectEvent.inTransaction(
        result.tx,
        blueDiamondLiquidity,
        "PriceOraclesModified",
        {
          USDTOracle: USDT_PRICE_ORACLE,
          BDTOracle: newOracleBDT,
        }
      );

      result = await blueDiamondLiquidity.oracleAddresses();
      expect(result[0]).to.equal(USDT_PRICE_ORACLE);
      expect(result[1]).to.equal(newOracleBDT);
    });
  });

  describe("Modify Token Addresses", () => {
    it("Should revert if the caller is not owner", async () => {
      let newBDT = "0xa8357bf572460fc40f4b0acacbb2a6a61c89f475"; // AAVE oracle

      await expect(
        blueDiamondLiquidity.connect(add1).modifyTokenAddresses(usdt, newBDT)
      ).to.be.revertedWith("NotOwner");
    });

    it("Should revert if the token addresses are zero address", async () => {
      let newBDT = constants.ZERO_ADDRESS; // zero address

      await expect(
        blueDiamondLiquidity.connect(admin).modifyTokenAddresses(usdt, newBDT)
      ).to.be.revertedWith("ZeroAddress");
    });

    it("Should modify the token addresses successfully", async () => {
      let newBDT = "0xA8357BF572460fC40f4B0aCacbB2a6A61c89f475"; // AAVE

      let result = await blueDiamondLiquidity
        .connect(admin)
        .modifyTokenAddresses(usdt, newBDT);

      expectEvent.inTransaction(
        result.tx,
        blueDiamondLiquidity,
        "TokenAddressesModified",
        {
          USDT: usdt,
          BDT: newBDT,
        }
      );

      result = await blueDiamondLiquidity.tokenAddresses();
      expect(result[0]).to.equal(usdt);
      expect(result[1]).to.equal(newBDT);
    });
  });

  describe("Modify Router Address", () => {
    it("Should revert if the caller is not owner", async () => {
      let newRouter = "0xa8357bf572460fc40f4b0acacbb2a6a61c89f475"; // AAVE oracle

      await expect(
        blueDiamondLiquidity.connect(add1).modifyRouterAddress(newRouter)
      ).to.be.revertedWith("NotOwner");
    });

    it("Should revert if the router address is zero address", async () => {
      let newRouter = constants.ZERO_ADDRESS; // zero address

      await expect(
        blueDiamondLiquidity.connect(admin).modifyRouterAddress(newRouter)
      ).to.be.revertedWith("ZeroAddress");
    });

    it("Should modify the router address successfully", async () => {
      let newRouter = "0xA8357BF572460fC40f4B0aCacbB2a6A61c89f475"; // AAVE

      let result = await blueDiamondLiquidity
        .connect(admin)
        .modifyRouterAddress(newRouter);

      expectEvent.inTransaction(
        result.tx,
        blueDiamondLiquidity,
        "RouterAddressModified",
        {
          router: newRouter,
        }
      );

      result = await blueDiamondLiquidity.routerAddress();
      expect(result).to.equal(newRouter);
    });
  });
});
