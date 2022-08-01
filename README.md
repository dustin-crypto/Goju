# GOJU: Short trading dapp

A dapp for short trading with the leverage of our VVS and tectonic. There are some derivative exchanges dapps that exists on other chains, and it is good to have this feature on Cronos chain as well, so this is my motivation for this project. 

So with a series of operations involving VVS and Tectonic we can actually short a token price with the provide of some collateral token assets.

**This project leverages hardhat framework**

this README contains how to run the code

## Setup

```shell
yarn install
```

## Run test cases

test case only supports mainnet! Please run this command in your local
```
yarn hardhat node --fork https://mainnet-archive.cronoslabs.com/v1/55e37d8975113ae7a44603ef8ce460aa
```

setup test case
```shell
yarn hardhat compile

yarn hardhat test test/Jujutsu2 --network localhost
```
