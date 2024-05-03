// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC private deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUSDpriceFeed;
    address weth;


    //users
    address alice = makeAddr('Alice');
    uint256 private constant INTITIAL_ETH_BALANCE = 20 ether;
    uint256 private constant COLLATERAL_AMOUNT = 10 ether;
    uint256 private constant INITIAL_TOKEN_BALANCE = 100 ether;
    

    function setUp() public {
      deployer = new DeployDSC();

      (dsc, engine, config) = deployer.run();
      (ethUSDpriceFeed,, weth,,) = config.activeNetworkConfig(); 
      vm.deal(alice, INTITIAL_ETH_BALANCE);

      ERC20Mock(weth).mint(alice, INITIAL_TOKEN_BALANCE);

    }

    // price Test

    function testGestUSDValue() public view {
      uint256 ethAmount = 15e18;
      // 15e18 * 2000/ETH = 30000e18
      uint256 expectedUSD = 30000e18;
  
      uint256 actualUSD = engine.getUsdValue(weth, ethAmount);

      assertEq(expectedUSD, actualUSD);
    }
  
    function testRevertsIfCollateralZero() public {
      vm.prank(alice);
      ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
     
      vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
      engine.depositCollateral(weth,0);

      vm.stopPrank();
    }

}
