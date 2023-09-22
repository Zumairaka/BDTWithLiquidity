require("@openzeppelin/hardhat-upgrades");

const { ethers, upgrades, network } = require("hardhat");
const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { constants } = require("@openzeppelin/test-helpers");
const expectEvent = require("@openzeppelin/test-helpers/src/expectEvent");

describe("Blue Diamond Token", () => {
  let admin, add1, add2, BDTToken, bdtToken;

  function getValue(value) {
    let amount = BigNumber.from(value).mul(
      BigNumber.from(10).pow(BigNumber.from(18))
    );

    return amount;
  }

  beforeEach(async () => {
    // initialize the signers
    [admin, add1, add2, _] = await ethers.getSigners();

    // deploy the contract using proxy
    BDTToken = await ethers.getContractFactory("BlueDiamondToken");
    bdtToken = await upgrades.deployProxy(BDTToken, {
      initializer: "initialize",
    });
    await bdtToken.deployed();
  });

  describe("Deploy", () => {
    it("Should set the details properly", async () => {
      let balance = getValue(7000000);
      expect(await bdtToken.owner()).to.equal(admin.address);
      expect(await bdtToken.totalSupply()).to.equal(balance);
      expect(await bdtToken.balanceOf(admin.address)).to.equal(balance);
      expect(await bdtToken.name()).to.equal("Blue Diamond Token");
      expect(await bdtToken.symbol()).to.equal("BDT");
    });
  });

  describe("Mint Tokens", () => {
    it("Should revert if the caller is not owner", async () => {
      let amount = getValue(100);
      await expect(
        bdtToken.connect(add2).mint(add1.address, amount)
      ).to.be.revertedWith("NotOwner");
    });

    it("Should revert if the amount is zero", async () => {
      let amount = getValue(100);

      await expect(
        bdtToken.connect(admin).mint(add1.address, 0)
      ).to.be.revertedWith("ZeroAmount");
    });

    it("Should revert if the account is zero address", async () => {
      let amount = getValue(100);

      await expect(
        bdtToken.connect(admin).mint(constants.ZERO_ADDRESS, amount)
      ).to.be.revertedWith("ZeroAddress");
    });

    it("Should mint the tokens by the owner properly", async () => {
      let amount = getValue(1000000);
      let total = getValue(8000000);

      // mint bdt tokens
      const receipt = await bdtToken.connect(admin).mint(add1.address, amount);
      expectEvent.inTransaction(receipt.tx, bdtToken, "MintedBDTtoken", {
        account: add1.address,
        amount: amount,
      });

      // check values
      expect(await bdtToken.balanceOf(add1.address)).to.equal(amount);
      expect(await bdtToken.totalSupply()).to.equal(total);
    });
  });

  describe("Burn Tokens", () => {
    it("Should revert if the caller is not owner", async () => {
      let amount = getValue(100);
      await expect(bdtToken.connect(add2).burn(amount)).to.be.revertedWith(
        "NotOwner"
      );
    });

    it("Should revert if the amount is zero", async () => {
      let amount = getValue(100);

      await expect(bdtToken.connect(admin).burn(0)).to.be.revertedWith(
        "ZeroAmount"
      );
    });

    it("Should revert if there is not enough balance with the owner to burn", async () => {
      let amount = getValue(1000000000);

      await expect(bdtToken.connect(admin).burn(amount)).to.be.revertedWith(
        "NotEnoughTokenToBurn"
      );
    });

    it("Should burn the tokens by the owner properly", async () => {
      let amount = getValue(1000000);
      let total = getValue(7000000);

      // burn double-fi tokens
      const receipt = await bdtToken.connect(admin).burn(amount);
      expectEvent.inTransaction(receipt.tx, bdtToken, "BurntBDTtoken", {
        amount: amount,
      });

      total = BigNumber.from(total).sub(BigNumber.from(amount));

      // check values
      expect(await bdtToken.balanceOf(admin.address)).to.equal(total);
      expect(await bdtToken.totalSupply()).to.equal(total);
    });
  });
});
