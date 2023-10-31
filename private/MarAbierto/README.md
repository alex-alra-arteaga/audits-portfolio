# Mar Abierto Audit by Racks Labs - Testing Documentation

## Table of Contents

1. [Introduction](#introduction)
2. [Running the Tests](#running-the-tests)
3. [Unit Tests with Hardhat](#unit-tests-with-hardhat)
4. [Reentrancy POC with Hardhat](#reentrancy-poc-with-hardhat)
5. [Fuzzing Tests with Echidna](#fuzzing-tests-with-echidna)

<a name="introduction"></a>
## Introduction

This document provides guidelines for running various tests in our system. These include unit tests, POC and fuzzing tests.

You can find the **Audit Report** and **OpenSea Testnet Report** in the `report/` directory.
And you can find both POC (Whitelist optimzation and ReentrancyAttack mock) in the `report/POC` directory.

The unic testing is present in the `test/unit/` folder, and the fuzzing in the `report/Echidna`.

<a name="running-the-tests"></a>
## Running the Tests

The commands mentioned in the following sections will guide you on how to run our automated testing suite.

<a name="unit-tests-with-hardhat"></a>
## Unit Tests with Hardhat

We use [Hardhat](https://hardhat.org/) for unit testing. To run these tests, simply execute the following command:

```bash
npx hardhat test
```

<a name="unit-tests-with-hardhat"></a>
## Reentrancy POC with Hardhat

```bash
npx hardhat test --grep "MarAbiertoToken Reentrancy POC"
```

<a name="fuzzing-tests-with-echidna"></a>
## Fuzzing Tests with Echidna

Echidna is used for performing invariant and fuzzing tests. It checks unusual combinations of function calls to verify if the invariant function, which should always hold true, fails under any circumstances.

**Note**: These tests are not deterministic, which means they may occasionally fail. The objective here is not to test for authorization but to ensure that the contract is secure against reentrancy attacks, overflows, and similar issues.

**Prerequisite**: Docker must be installed and running on your machine.

To run the Echidna tests, use the following commands:

```bash
docker run -it --rm -v $PWD:/code trailofbits/eth-security-toolbox
cd /code/report/Echidna
echidna-test contracts/TestEchidnaFlatten.sol --contract TestMarAbiertoToken
```
