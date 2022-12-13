# Staking contract (using slope intercept formula)

The main objective of this contract is to calculate the apy using slope-intercept formula and the motivation behind that
sometimes apy might not be linear, as an example: For 1000 tokens user might get %1 apy, but what if user gets %9 apy at
100.000 tokens instead of 9000 ?!

An example graph: https://www.desmos.com/calculator/woto8v1fmc

Warning: Be aware, this contract written just for concept and it's not optimized for gas usage and it's not tested
properly !!!

## Installation

### Pre Requisites

Before running any command, you need to create a .env file and set a BIP-39 compatible mnemonic as an environment
variable. Follow the example in .env.example. If you don't already have a mnemonic, use this
[website](https://iancoleman.io/bip39/) to generate one.

1. Install node and npm
2. Install yarn

```bash
npm install --global yarn
```

Check that Yarn is installed by running:

```bash
yarn --version
```

Then, proceed with installing dependencies:

```bash
yarn install
```

## Usage/Examples

### Compile

Compile the smart contracts with Hardhat:

```bash
yarn compile
```

### TypeChain

Compile the smart contracts and generate TypeChain artifacts:

```bash
yarn typechain
```

### Lint Solidity and TypeScript

Lint the Solidity and TypeScript code (then check with prettier):

```bash
yarn lint
```

### Clean

Delete the smart contract artifacts, the coverage reports and the Hardhat cache:

```bash
yarn clean
```

### Available Tasks

To see available tasks from Hardhat:

```bash
npx hardhat
```

## Running Tests

### Test

To run tests, run the following command:

```bash
yarn test
```

### Test with gas reportage

To report gas after test, set `REPORT_GAS="true"` on `.env` file. Then run test.

### Coverage

Generate the code coverage report:

```bash
yarn coverage
```

## Contributing

For git linting [commitlint](https://github.com/conventional-changelog/commitlint) is being used.
[This website](https://commitlint.io/) can be helpful to write commit messages.
