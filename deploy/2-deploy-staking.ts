import { Deployer } from '@matterlabs/hardhat-zksync-deploy';
import { Wallet } from 'zksync-web3';
import chalk from 'chalk';
import * as hre from 'hardhat';

import { ChainConfig } from "./config";
import { readJson, writeJson } from "./fileutil";

async function main() {
    let chainConfig = ChainConfig.ZkSyncTest;
    const isUpgrade = false;

    const zkWallet = new Wallet(chainConfig.privateKey);
    const deployer = new Deployer(hre, zkWallet);

    const contractName = 'Staking';
    // deploy proxy
    if(!isUpgrade) {
        console.log("Deploying " + contractName + "...");
        const contract = await deployer.loadArtifact(contractName);
        
        const staingCC = await hre.zkUpgrades.deployProxy(deployer.zkWallet, contract, [chainConfig.admin, 430], { initializer: 'initialize' });
        await staingCC.deployed();
        
        await writeJson([[contractName, staingCC.address]]);
        const days = [14,45,90,180,365];
        const ratios = [1890,2650,4740,7830,13670];
        await staingCC.addPlan(days, ratios);
    } else {
        // upgrade proxy implementation
        let obj = await readJson()
        const v2Contract = await deployer.loadArtifact(contractName);
        const upgradedBox = await hre.zkUpgrades.upgradeProxy(deployer.zkWallet, obj[contractName], v2Contract);
        console.info(chalk.green('Successfully upgraded '+contractName+' to ', upgradedBox.address));
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});