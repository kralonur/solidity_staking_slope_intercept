import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Signers } from "../types";
import { shouldBehaveLikeStaking } from "./Staking.behavior";
import { deployStakingFixture } from "./Staking.fixture";

describe("Staking tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.user1 = signers[1];
    this.signers.user2 = signers[2];
    this.signers.user3 = signers[3];
    this.signers.user4 = signers[4];

    this.loadFixture = loadFixture;
  });

  describe("Staking", function () {
    before(async function () {
      const { stakingToken, staking } = await this.loadFixture(deployStakingFixture);
      this.stakingToken = stakingToken;
      this.staking = staking;
    });

    shouldBehaveLikeStaking();
  });
});
