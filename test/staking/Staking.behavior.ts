import { increase, latest } from "@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time";
import { years } from "@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time/duration";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

type BigNumberRecord = Record<string, BigNumber>;

let tokenDecimals: BigNumber;
const amountStakedStorage: BigNumberRecord = {};
const availableRewardStorage: BigNumberRecord = {};
const lastUpdateTimeStorage: BigNumberRecord = {};

export function shouldBehaveLikeStaking() {
  it("Should stake (initial state)", async function () {
    tokenDecimals = BigNumber.from(await this.stakingToken.decimals());
    const amounts: BigNumberRecord = {};

    // Set stake amount for the users
    amounts[this.signers.user1.address] = ethers.utils.parseUnits("1000", tokenDecimals);
    amounts[this.signers.user2.address] = ethers.utils.parseUnits("500", tokenDecimals);
    amounts[this.signers.user3.address] = ethers.utils.parseUnits("200000", tokenDecimals);

    // Set available reward storage to 0 (since it's initial stake)
    availableRewardStorage[this.signers.user1.address] = BigNumber.from(0);
    availableRewardStorage[this.signers.user2.address] = BigNumber.from(0);
    availableRewardStorage[this.signers.user3.address] = BigNumber.from(0);

    // Mint and approve amount for the users
    for (const user of Object.keys(amounts)) {
      await this.stakingToken.mint(user, amounts[user]);
      const signer = await ethers.getSigner(user);
      await this.stakingToken.connect(signer).approve(this.staking.address, amounts[user]);
    }

    // Stake for the users
    for (const user of Object.keys(amounts)) {
      const signer = await ethers.getSigner(user);
      await this.staking.connect(signer).stake(amounts[user]);

      // Update amount staked
      amountStakedStorage[user] = amounts[user];
      // Update last update time
      lastUpdateTimeStorage[user] = BigNumber.from(await latest());
    }
  });

  it("Give details (after half year)", async function () {
    await increase(years(1) / 2);

    console.log("🚀 ~ details for", this.signers.user1.address);
    const staker1Details = await this.staking.getStakerDetails(this.signers.user1.address);
    console.log("🚀 ~ details for", this.signers.user2.address);
    const staker2Details = await this.staking.getStakerDetails(this.signers.user2.address);
    console.log("🚀 ~ details for", this.signers.user3.address);
    const staker3Details = await this.staking.getStakerDetails(this.signers.user3.address);

    console.log("🚀 ~ staker1Details", staker1Details);
    console.log("🚀 ~ staker2Details", staker2Details);
    console.log("🚀 ~ staker3Details", staker3Details);
  });

  it("Give details (after a year)", async function () {
    const minApy = ethers.utils.parseEther("0.02");
    const minAmount = ethers.utils.parseUnits("1000", tokenDecimals);
    const maxApy = ethers.utils.parseEther("0.18");
    const maxAmount = ethers.utils.parseUnits("100000", tokenDecimals);

    await this.staking.updateParameter(minApy, minAmount, maxApy, maxAmount);

    await increase(years(1) / 2);

    console.log("🚀 ~ details for", this.signers.user1.address);
    const staker1Details = await this.staking.getStakerDetails(this.signers.user1.address);
    console.log("🚀 ~ details for", this.signers.user2.address);
    const staker2Details = await this.staking.getStakerDetails(this.signers.user2.address);
    console.log("🚀 ~ details for", this.signers.user3.address);
    const staker3Details = await this.staking.getStakerDetails(this.signers.user3.address);

    console.log("🚀 ~ staker1Details", staker1Details);
    console.log("🚀 ~ staker2Details", staker2Details);
    console.log("🚀 ~ staker3Details", staker3Details);
  });

  it("Should claim rewards", async function () {
    // approve bunch of token for claimRewards
    await this.stakingToken.mint(this.signers.admin.address, ethers.utils.parseUnits("10000000", tokenDecimals));
    await this.stakingToken.approve(this.staking.address, ethers.utils.parseUnits("10000000", tokenDecimals));

    const staker1BalanceBefore = await this.stakingToken.balanceOf(this.signers.user1.address);
    const staker3BalanceBefore = await this.stakingToken.balanceOf(this.signers.user3.address);

    await this.staking.connect(this.signers.user1).claimRewards();
    await this.staking.connect(this.signers.user3).claimRewards();

    const staker1DeltaBalance = (await this.stakingToken.balanceOf(this.signers.user1.address)).sub(
      staker1BalanceBefore,
    );
    const staker3DeltaBalance = (await this.stakingToken.balanceOf(this.signers.user3.address)).sub(
      staker3BalanceBefore,
    );

    console.log("🚀 ~ staker1DeltaBalance", staker1DeltaBalance);
    console.log("🚀 ~ staker3DeltaBalance", staker3DeltaBalance);

    expect(staker1DeltaBalance).to.approximately(
      ethers.utils.parseUnits("15", tokenDecimals),
      ethers.utils.parseUnits("0.01", tokenDecimals),
    );

    expect(staker3DeltaBalance).to.approximately(
      ethers.utils.parseUnits("27000", tokenDecimals),
      ethers.utils.parseUnits("0.01", tokenDecimals),
    );
  });
}
