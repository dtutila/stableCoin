// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from  "../mocks/MockV3Aggregator.sol";


contract DSCEngineTest is Test {
    DeployDSC private deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUSDpriceFeed;
    address weth;
    address btcUSDPriceFed;
    address wbtc;
    uint256 deployerKey;

    //users
    address alice = makeAddr("Alice");
    uint256 private constant INTITIAL_ETH_BALANCE = 20 ether;
    uint256 private constant COLLATERAL_AMOUNT = 10 ether;
    uint256 private constant INITIAL_TOKEN_BALANCE = 100 ether;

    address[] private tokenAddresses;
    address[] private priceFeeAddresses;


     modifier depositedCollateral() {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }


    function setUp() public {
        deployer = new DeployDSC();

        (dsc, engine, config) = deployer.run();
        (ethUSDpriceFeed,btcUSDPriceFed, weth, wbtc, deployerKey) = config.activeNetworkConfig();
        vm.deal(alice, INTITIAL_ETH_BALANCE);

        ERC20Mock(weth).mint(alice, INITIAL_TOKEN_BALANCE);
    }

    //test constructor
    function testREvertsIfTokenLengthDesNotMatch() public {
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        priceFeeAddresses.push(ethUSDpriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressessAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeeAddresses, address(dsc));

      
    }
    // price Test

    function testGestUSDValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30000e18
        uint256 expectedUSD = 30000e18;

        uint256 actualUSD = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUSD, actualUSD);
    }

    function testGetTestTokenAMounfFromUSD() public view {
      uint256 usdAmount = 100 ether;
      uint256 expectedWeth = 0.05 ether;
      
      uint256 actualWeth = engine.getTokenAmountFromUSD(weth, usdAmount);

      assertEq(expectedWeth, actualWeth);     
    }

    // collateral 
    
    function testRevertsIfCollateralZero() public {
        vm.prank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);

        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        engine.depositCollateral(weth, 0);

        vm.stopPrank();
    }


    function testRevertsWithUnapprovedCollateral() public {
      ERC20Mock ran = new ERC20Mock('R', 'r', alice, INITIAL_TOKEN_BALANCE);
      vm.startPrank(alice);
      vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
      engine.depositCollateral(address(ran), COLLATERAL_AMOUNT);
      vm.stopPrank();

    }
    
    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral() {
      (uint256 totalDSCMinted, uint256 colateralValueInUSD) = engine.getAccountInformation(alice);

      uint256 expectedTotalDSCMinted = 0; 
      uint256 expectedDepositAmount = engine.getTokenAmountFromUSD(weth, colateralValueInUSD);
      
      assertEq(totalDSCMinted, expectedTotalDSCMinted);
      assertEq(COLLATERAL_AMOUNT, expectedDepositAmount);
      
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(alice);
        assertEq(userBalance, 0);
    }

    // deposit collateral and mint 

     function testRevertsIfMintedDSCBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUSDpriceFeed).latestRoundData();
        uint256 amountToMint = (COLLATERAL_AMOUNT * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);

        uint256 expectedHealthFactor = engine.calculateHealthFactor(amountToMint, engine.getUsdValue(weth, COLLATERAL_AMOUNT));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, amountToMint);
        vm.stopPrank();
    }

}
