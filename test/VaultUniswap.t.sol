// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./AbstractVault.t.sol";
import "./shared/AbstractUniswapHelper.sol";

contract MainnetUniswapVaultTest is
    MainnetUniswapTestSuite,
    AbstractVaultTest,
    AbstractMainnetForkTest,
    AbstractMainnetUniswapConfigContract
{}

contract PolygonUniswapVaultTest is
    PolygonUniswapTestSuite,
    AbstractVaultTest,
    AbstractPolygonForkTest,
    AbstractPolygonUniswapConfigContract
{}
