require("@openzeppelin/hardhat-upgrades");
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`BDT Token is deploying with the account ${deployer.address}`);

  const BdtToken = await ethers.getContractFactory("BlueDiamondToken");
  const bdtToken = await upgrades.deployProxy(BdtToken, {
    initializer: "initialize",
  });

  await bdtToken.deployed();
  console.log(`BDT Token is deployed to the address ${bdtToken.address}`);
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
