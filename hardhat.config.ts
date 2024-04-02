import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-deploy";
// upgradable plugin
import "@matterlabs/hardhat-zksync-upgradable";

import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

// dynamically changes endpoints for local tests
const zkSyncTestnet =
  process.env.NODE_ENV == "test"
    ? {
        url: "http://localhost:3050",
        ethNetwork: "http://localhost:8545",
        zksync: true,
      }
    : {
        url: "https://mainnet.era.zksync.io",
        ethNetwork: "ethereum",
        zksync: true
      };
/*
{
        //url: "https://zksync2-testnet.zksync.dev",
        url: "https://testnet.era.zksync.dev",
        ethNetwork: "goerli",
        zksync: true
      }
*/
const config: HardhatUserConfig = {
  zksolc: {
    version: "1.3.14",
    //version: 'latest',
    compilerSource: 'binary',
    settings: {
        optimizer: {
            enabled: true,
        },
    },
  },
  defaultNetwork: "zkSyncTestnet",
  networks: {
    hardhat: {
      zksync: false,
    },
    goerli: {
      url: 'https://goerli.infura.io/v3/xxxxxxxxx'
    },
    zkSyncTestnet,
  },
  solidity: {
    version: "0.8.12",
  },
};

export default config;
