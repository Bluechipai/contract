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

    let obj = await readJson();
    const contractName = 'MyToken';

    // deploy proxy
    if(!isUpgrade) {
        console.log("Deploying " + contractName + "...");
        const contract = await deployer.loadArtifact(contractName);

        //USDT
        let amount = hre.ethers.utils.parseEther('100000000');
        const token = await hre.zkUpgrades.deployProxy(deployer.zkWallet, contract, ['USDT', 'USDT', amount, 6], { initializer: 'initialize' });
        await token.deployed();
        console.log(contractName + " deployed to:", token.address);
        await writeJson([["USDT", token.address]]);

        //plat token
        /*
        let amount = hre.ethers.utils.parseEther('100000000');
        const platToken = await hre.zkUpgrades.deployProxy(deployer.zkWallet, contract, ['Chip', 'Chip', amount, 18], { initializer: 'initialize' });
        await platToken.deployed();
        await writeJson([["Chip", platToken.address]]);
        */
        //subscribe token
        amount = hre.ethers.utils.parseEther('100000000');
        const gttToken = await hre.zkUpgrades.deployProxy(deployer.zkWallet, contract, ['GTT', 'GTT', amount, 18], { initializer: 'initialize' });
        await gttToken.deployed();
        await writeJson([["GTT", gttToken.address]]);
    } else {
        // upgrade proxy implementation
        const TokenV2 = await deployer.loadArtifact(contractName);
        const upgradedBox = await hre.zkUpgrades.upgradeProxy(deployer.zkWallet, obj['USDT'], TokenV2);
        console.info(chalk.green('Successfully upgraded '+contractName+' to ',upgradedBox.address));
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});