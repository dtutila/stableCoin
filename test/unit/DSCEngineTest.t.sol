// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DSCEngineTest is Test {
    DeployDSC private deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUSDpriceFeed;
    address weth;

    function setUp() public {
      deployer = new DeployDSC();

      (dsc, engine, config) = deployer.run();
      (ethUSDpriceFeed,, weth,,) = config.activeNetworkConfig(); 

    }

    // price Test

    function testGestUSDValue() public {
      uint256 ethAmount = 15e18;
      // 15e18 * 2000/ETH = 30000e18
      uint256 expectedUSD = 30000e18;
  
      uint256 actualUSD = engine.getUsdValue(weth, ethAmount);

      assertEq(expectedUSD, actualUSD);

    }
}
