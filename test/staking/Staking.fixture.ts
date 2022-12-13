import { days } from "@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time/duration";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import { ERC20Token, ERC20Token__factory, Staking, Staking__factory } from "../../types";

export type StakingFixture = {
  stakingToken: ERC20Token;
  staking: Staking;
};

export async function deployStakingFixture(): Promise<StakingFixture> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const admin: SignerWithAddress = signers[0];

  const tokenFactory: ERC20Token__factory = <ERC20Token__factory>await ethers.getContractFactory("ERC20Token");
  const tokenContract: ERC20Token = <ERC20Token>await tokenFactory.connect(admin).deploy("TEST", "TST", 10000);
  await tokenContract.deployed();

  const tokenStaking = tokenContract.address;
  const treasuryAddress = admin.address;

  const minClaimAmount = 1;
  const stakeLockPeriod = days(30);
  const claimUnlockPeriod = days(14);
  const unstakeExtendPeriod = days(14);
  const earlyUnstakeFine = 3000;
  const minApy = ethers.utils.parseEther("0.01");
  const minAmount = ethers.utils.parseUnits("1000", await tokenContract.decimals());
  const maxApy = ethers.utils.parseEther("0.09");
  const maxAmount = ethers.utils.parseUnits("100000", await tokenContract.decimals());

  const stakingFactory: Staking__factory = <Staking__factory>await ethers.getContractFactory("Staking");
  const stakingContract: Staking = <Staking>(
    await stakingFactory
      .connect(admin)
      .deploy(
        tokenStaking,
        treasuryAddress,
        minClaimAmount,
        stakeLockPeriod,
        claimUnlockPeriod,
        unstakeExtendPeriod,
        earlyUnstakeFine,
        minApy,
        minAmount,
        maxApy,
        maxAmount,
      )
  );
  await stakingContract.deployed();

  return { stakingToken: tokenContract, staking: stakingContract };
}
