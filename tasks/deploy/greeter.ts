import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import fs from "fs-extra";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type { Greeter } from "../../types/Greeter";
import type { Greeter__factory } from "../../types/factories/Greeter__factory";

task("deploy:Greeter").setAction(async function (_taskArguments: TaskArguments, { ethers }) {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const factory: Greeter__factory = <Greeter__factory>await ethers.getContractFactory("Greeter");
  const args = getContractArgs();
  const contract: Greeter = <Greeter>await factory.connect(signers[0]).deploy(args.greeting);
  await contract.deployed();
  console.log("Greeter deployed to: ", contract.address);
});

function getContractArgs() {
  const json = fs.readJSONSync("./deployargs/deployGreeterArgs.json");

  const greeting = String(json.greeting);

  return { greeting: greeting };
}
