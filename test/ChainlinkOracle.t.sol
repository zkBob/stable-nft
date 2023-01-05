// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./SetupContract.sol";
import "./mocks/MockOracle.sol";
import "./mocks/MockChainlinkOracle.sol";
import "./shared/ForkTests.sol";

contract ChainlinkOracleTest is Test, SetupContract, AbstractMainnetForkTest {
    event OraclesAdded(
        address indexed origin,
        address indexed sender,
        address[] tokens,
        address[] oracles,
        uint48[] heartbeats
    );
    event ValidPeriodUpdated(address indexed origin, address indexed sender, uint256 validPeriod);
    event PricePosted(
        address indexed origin,
        address indexed sender,
        address token,
        uint256 newPriceX96,
        uint48 fallbackUpdatedAt
    );

    uint256 YEAR = 365 * 24 * 60 * 60;

    ChainlinkOracle oracle;

    constructor() {
        UniV3PositionManager = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        UniV3Factory = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        SwapRouter = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);

        wbtc = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        ape = address(0x4d224452801ACEd8B2F0aebE155379bb5D594381);

        chainlinkBtc = address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
        chainlinkUsdc = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        chainlinkEth = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

        tokens = [wbtc, usdc, weth];
        chainlinkOracles = [chainlinkBtc, chainlinkUsdc, chainlinkEth];
        heartbeats = [4000, 360000, 4000];
    }

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, forkBlock);
        oracle = deployChainlink();
    }

    // hasOracle

    function testHasOracleExistedToken() public {
        for (uint256 i = 0; i < 3; ++i) {
            assertTrue(oracle.hasOracle(tokens[i]));
        }
    }

    function testHasOracleNonExistedToken() public {
        assertFalse(oracle.hasOracle(getNextUserAddress()));
    }

    // addChainlinkOracles

    function testAddChainlinkOraclesSuccess() public {
        address[] memory emptyTokens = new address[](0);
        address[] memory emptyOracles = new address[](0);
        uint48[] memory emptyHeartbeats = new uint48[](0);
        ChainlinkOracle currentOracle = new ChainlinkOracle(emptyTokens, emptyOracles, emptyHeartbeats, 3600);

        currentOracle.addChainlinkOracles(tokens, chainlinkOracles, heartbeats);

        for (uint256 i = 0; i < 3; ++i) {
            assertTrue(currentOracle.hasOracle(tokens[i]));
        }
    }

    function testAddChainlinkOraclesEmit() public {
        address[] memory emptyTokens = new address[](0);
        address[] memory emptyOracles = new address[](0);
        uint48[] memory emptyHeartbeats = new uint48[](0);
        ChainlinkOracle currentOracle = new ChainlinkOracle(emptyTokens, emptyOracles, emptyHeartbeats, 3600);

        vm.expectEmit(false, true, false, true);
        emit OraclesAdded(getNextUserAddress(), address(this), tokens, chainlinkOracles, heartbeats);
        currentOracle.addChainlinkOracles(tokens, chainlinkOracles, heartbeats);
    }

    function testAddChainlinkOraclesWhenInvalidValue() public {
        address[] memory currentTokens = new address[](1);
        currentTokens[0] = wbtc;
        address[] memory currentOracles = new address[](0);

        vm.expectRevert(ChainlinkOracle.InvalidLength.selector);
        oracle.addChainlinkOracles(currentTokens, currentOracles, heartbeats);
    }

    // price

    function testPrice() public {
        (bool wethSuccess, uint256 wethPriceX96) = oracle.price(weth);
        (bool usdcSuccess, uint256 usdcPriceX96) = oracle.price(usdc);
        (bool wbtcSuccess, uint256 wbtcPriceX96) = oracle.price(wbtc);
        assertEq(wethSuccess, true);
        assertEq(usdcSuccess, true);
        assertEq(wbtcSuccess, true);
        assertApproxEqual(1500, wethPriceX96 >> 96, 500);
        assertApproxEqual(10**12, usdcPriceX96 >> 96, 50);
        assertApproxEqual(20000 * (10**10), wbtcPriceX96 >> 96, 500);
    }

    function testPriceReturnsZeroForNonSetToken() public {
        (bool success, uint256 priceX96) = oracle.price(getNextUserAddress());
        assertEq(success, false);
        assertEq(priceX96, 0);
    }

    function testOracleNotAddedForBrokenOracle() public {
        MockChainlinkOracle mockOracle = new MockChainlinkOracle();

        address[] memory currentTokens = new address[](1);
        currentTokens[0] = ape;
        address[] memory currentOracles = new address[](1);
        currentOracles[0] = address(mockOracle);
        uint48[] memory currentHeartbeats = new uint48[](1);
        currentHeartbeats[0] = 1500;

        vm.expectRevert(ChainlinkOracle.InvalidOracle.selector);
        oracle.addChainlinkOracles(currentTokens, currentOracles, currentHeartbeats);
    }

    // setValidPeriod

    function testSetValidPeriodSuccess() public {
        oracle.setValidPeriod(500);
        assertEq(oracle.validPeriod(), 500);
    }

    function testSetValidPeriodEmit() public {
        vm.expectEmit(false, true, false, true);
        oracle.setValidPeriod(500);
        emit ValidPeriodUpdated(getNextUserAddress(), address(this), 500);
    }

    function testSetValidPeriodWhenNotOwner() public {
        vm.prank(getNextUserAddress());
        vm.expectRevert("Ownable: caller is not the owner");
        oracle.setValidPeriod(500);
    }

    // setUnderlyingPriceX96

    function testSetUnderlyingPriceX96Success() public {
        address[] memory currentTokens = new address[](1);
        currentTokens[0] = ape;
        address[] memory currentOracles = new address[](1);
        currentOracles[0] = chainlinkOracles[0];
        uint48[] memory currentHeartbeats = new uint48[](1);
        currentHeartbeats[0] = 1500;

        oracle.addChainlinkOracles(currentTokens, currentOracles, currentHeartbeats);

        vm.warp(block.timestamp + YEAR);

        (bool success, uint256 priceX96) = oracle.price(ape);
        assertEq(success, false);
        oracle.setUnderlyingPriceX96(ape, 30 << 96, uint48(block.timestamp));
        (success, priceX96) = oracle.price(ape);
        assertEq(success, true);
        assertEq(priceX96, 30 << 96);
    }

    function testSetUnderlyingPriceX96Emit() public {
        address[] memory currentTokens = new address[](1);
        currentTokens[0] = ape;
        address[] memory currentOracles = new address[](1);
        currentOracles[0] = chainlinkOracles[0];
        uint48[] memory currentHeartbeats = new uint48[](1);
        currentHeartbeats[0] = 1500;

        oracle.addChainlinkOracles(currentTokens, currentOracles, currentHeartbeats);

        vm.expectEmit(false, true, false, true);
        emit PricePosted(getNextUserAddress(), address(this), ape, 30 << 96, uint48(block.timestamp));
        oracle.setUnderlyingPriceX96(ape, 30 << 96, uint48(block.timestamp));
    }

    function testSetUnderlyingPriceX96WhenNotOwner() public {
        address[] memory currentTokens = new address[](1);
        currentTokens[0] = ape;
        address[] memory currentOracles = new address[](1);
        currentOracles[0] = chainlinkOracles[0];
        uint48[] memory currentHeartbeats = new uint48[](1);
        currentHeartbeats[0] = 1500;

        oracle.addChainlinkOracles(currentTokens, currentOracles, currentHeartbeats);

        vm.prank(getNextUserAddress());
        vm.expectRevert("Ownable: caller is not the owner");
        oracle.setUnderlyingPriceX96(ape, 30 << 96, uint48(block.timestamp));
    }

    function testSetUnderlyingPriceX96WhenPriceIsTooOld() public {
        address[] memory currentTokens = new address[](1);
        currentTokens[0] = ape;
        address[] memory currentOracles = new address[](1);
        currentOracles[0] = chainlinkOracles[0];
        uint48[] memory currentHeartbeats = new uint48[](1);
        currentHeartbeats[0] = 1500;

        oracle.addChainlinkOracles(currentTokens, currentOracles, currentHeartbeats);

        vm.expectRevert(ChainlinkOracle.PriceUpdateFailed.selector);
        oracle.setUnderlyingPriceX96(ape, 30 << 96, uint48(block.timestamp) - 86400);
    }
}
