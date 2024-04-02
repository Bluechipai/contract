### Smart contracts for IDO usecase

https://github.com/matter-labs/hardhat-zksync/tree/main/examples

## Features
- Support contract upgradeable
- Solidity 0.8.x
- Governance
- Lazy-minting for ERC721 and ERC1155
- Contract factory for INO
## Set up
Node >= 10.x && yarn > 1.x
```
$ node --version
v16.13.0

$ npm install --global yarn

$ yarn --version
1.22.17
```

Install dependencies
```
$ yarn
```
## Test
1. Compile contract
```
$ yarn hardhat compile
```
2. Run tests
```
$ yarn test
```
## Run scripts
```
yarn hardhat run ./deploy/0-deploy-test-token.ts

yarn hardhat run ./deploy/1-deploy-call.ts

yarn hardhat run ./deploy/2-deploy-staking.ts

yarn hardhat run ./deploy/3-deploy-plat-token.ts
```

For more information, you can check this link [here](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies)
## Solidity linter and prettiers
1. Run linter to analyze convention and security for smart contracts
```
$ yarn sol:linter
```
2. Format smart contracts
```
$ yarn sol:prettier
```
3. Format typescript scripts for unit tests, deployment and upgrade
```
$ yarn ts:prettier
```

* Note: Updated husky hook for pre-commit