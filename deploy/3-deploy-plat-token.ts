import { Deployer } from '@matterlabs/hardhat-zksync-deploy';
import { Wallet } from 'zksync-web3';
import chalk from 'chalk';
import * as hre from 'hardhat';
import * as ethers from "ethers";
import { ChainConfig } from "./config";
import { readJson, writeJson } from "./fileutil";

async function main() {
    let chainConfig = ChainConfig.ZkSyncTest;
    const isUpgrade = false;

    const zkWallet = new Wallet(chainConfig.privateKey);
    const deployer = new Deployer(hre, zkWallet);

    let obj = await readJson();
    const contractName = 'ChipToken';
    
    // deploy proxy
    if(!isUpgrade) {
        console.log("Deploying " + contractName + "...");
        //plat token
        const artifactChipToken = await deployer.loadArtifact(contractName);
        let amount = hre.ethers.utils.parseEther('1000000000');
        console.log("amount:="+amount.toString());
        console.log("Staking:="+obj['Staking']);

        const tokenCC = await deployer.deploy(artifactChipToken, [chainConfig.admin, obj['Staking'], 'CHIP', 'CHIP', 18, amount]);
        await writeJson([["Chip", tokenCC.address]]);
    } else {
        // upgrade proxy implementation
        const V2Contract = await deployer.loadArtifact(contractName);
        const upgradedBox = await hre.zkUpgrades.upgradeProxy(deployer.zkWallet, obj['Chip'], V2Contract);
        console.info(chalk.green('Successfully upgraded '+contractName+' to ',upgradedBox.address));
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});