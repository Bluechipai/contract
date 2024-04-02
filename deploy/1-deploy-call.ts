import { Deployer } from '@matterlabs/hardhat-zksync-deploy';
import { Wallet } from 'zksync-web3';
import * as hre from 'hardhat';

import { ChainConfig } from "./config";
import { readJson, writeJson } from "./fileutil";

async function main() {
    let chainConfig = ChainConfig.ZkSyncTest;

    const zkWallet = new Wallet(chainConfig.privateKey);
    const deployer = new Deployer(hre, zkWallet);

    const contractName = 'Multicall';
    // deploy proxy
    console.log("Deploying " + contractName + "...");

    const contract = await deployer.loadArtifact(contractName);
    const callCC = await deployer.deploy(contract);
    await callCC.deployed();

    console.log(contractName + " deployed to:", callCC.address);
    await writeJson([["multicall", callCC.address]]);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});