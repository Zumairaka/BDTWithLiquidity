require("@openzeppelin/hardhat-upgrades");
const { ethers, upgrades } = require("hardhat");

async function main() {
  // bnb testnet addresses
  const usdtTest = "0x35D12f9065D49d5123D8AcC1fBE5af6c667F2559";
  const bdtTest = "0x27Ea149AA561EB9dd9e7b609977e31f48C26ec4a";
  const routerTest = "0xd99d1c33f9fc3444f8101754abc46c52416550d1";
  const usdtOracle = "0xEca2605f0BCF2BA5966372C99837b1F182d3D620";

  // bnb mainnet addresses
  const usdtMainnet = "";
  const bdtMainnet = "";
  const routerMainnet = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
  const usdtOracleMainnet = "0xB97Ad0E74fa7d920791E90258A6E2085088b4320";

  const [deployer] = await ethers.getSigners();

  // deploy blue diamond liquidity
  console.log(
    `BDT Token Liquidity without private is deploying with the account ${deployer.address}`
  );

  const BdtLiquidity = await ethers.getContractFactory("BlueDiamondLiquidity");
  const bdtLiquidity = await upgrades.deployProxy(
    BdtLiquidity,
    [usdtTest, bdtTest, routerTest, usdtOracle],
    {
      initializer: "initialize",
    }
  );

  await bdtLiquidity.deployed();
  console.log(
    `BDT Token Liquidity is deployed to the address ${bdtLiquidity.address}`
  );
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
