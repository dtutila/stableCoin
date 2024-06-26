// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";

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
    address private alice = makeAddr("Alice");
    address private liquidator = makeAddr("Liquidator");
    uint256 private COLLATERAL_TO_COVER = 20 ether;
    uint256 private constant INTITIAL_ETH_BALANCE = 20 ether;
    uint256 private constant COLLATERAL_AMOUNT = 10 ether;
    uint256 private constant INITIAL_TOKEN_BALANCE = 100 ether;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    address[] private tokenAddresses;
    address[] private priceFeeAddresses;

    modifier depositedCollateral() {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMint() {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, INITIAL_TOKEN_BALANCE);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployDSC();

        (dsc, engine, config) = deployer.run();
        (ethUSDpriceFeed, btcUSDPriceFed, weth, wbtc, deployerKey) = config.activeNetworkConfig();
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
        ERC20Mock ran = new ERC20Mock("R", "r", alice, INITIAL_TOKEN_BALANCE);
        vm.startPrank(alice);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(ran), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
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
        uint256 amountToMint =
            (COLLATERAL_AMOUNT * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);

        uint256 expectedHealthFactor =
            engine.calculateHealthFactor(amountToMint, engine.getUsdValue(weth, COLLATERAL_AMOUNT));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, amountToMint);
        vm.stopPrank();
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMint {
        uint256 userBalance = dsc.balanceOf(alice);
        assertEq(userBalance, INITIAL_TOKEN_BALANCE);
    }

    function testCanMintDsc() public depositedCollateral {
        vm.prank(alice);
        engine.mintDSC(INITIAL_TOKEN_BALANCE);

        uint256 userBalance = dsc.balanceOf(alice);
        assertEq(userBalance, INITIAL_TOKEN_BALANCE);
    }

    //hf tests

    function testProperlyReportsHealthFactor() public depositedCollateralAndMint {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = engine.getHealthFactor(alice);

        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMint {
        int256 ethUsdUpdatedPrice = 18e8;

        MockV3Aggregator(ethUSDpriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = engine.getHealthFactor(alice);
        assert(userHealthFactor == 0.9 ether);
    }

    // burn test
    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, INITIAL_TOKEN_BALANCE);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        engine.burnDSC(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(alice);
        vm.expectRevert();
        engine.burnDSC(1);
    }

    function testCanBurnDsc() public depositedCollateralAndMint {
        vm.startPrank(alice);
        dsc.approve(address(engine), INITIAL_TOKEN_BALANCE);
        engine.burnDSC(INITIAL_TOKEN_BALANCE);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(alice);
        assertEq(userBalance, 0);
    }

    //reedem collateral

    function testMustRedeemMoreThanZero() public depositedCollateralAndMint {
        vm.startPrank(alice);
        dsc.approve(address(engine), INITIAL_TOKEN_BALANCE);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        engine.redeemCollateralForDSC(weth, 0, INITIAL_TOKEN_BALANCE);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, INITIAL_TOKEN_BALANCE);
        dsc.approve(address(engine), INITIAL_TOKEN_BALANCE);
        engine.redeemCollateralForDSC(weth, COLLATERAL_AMOUNT, INITIAL_TOKEN_BALANCE);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(alice);
        assertEq(userBalance, 0);
    }
    //liquidation

    function testMustImproveHealthFactorOnLiquidation() public {
        // Arrange - Setup
        MockMoreDebtDSC mockDsc = new MockMoreDebtDSC(ethUSDpriceFeed);
        tokenAddresses = [weth];
        priceFeeAddresses = [ethUSDpriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeeAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(mockDsce), COLLATERAL_AMOUNT);
        mockDsce.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, INITIAL_TOKEN_BALANCE);
        vm.stopPrank();

        // Arrange - Liquidator
        uint256 collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockDsce), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockDsce.depositCollateralAndMintDSC(weth, collateralToCover, INITIAL_TOKEN_BALANCE);
        mockDsc.approve(address(mockDsce), debtToCover);
        // Act
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUSDpriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Act/Assert
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        mockDsce.liquidate(weth, alice, debtToCover);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMint {
        ERC20Mock(weth).mint(liquidator, COLLATERAL_TO_COVER);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_TO_COVER);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_TO_COVER, INITIAL_TOKEN_BALANCE);
        dsc.approve(address(engine), INITIAL_TOKEN_BALANCE);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOK.selector);
        engine.liquidate(weth, alice, INITIAL_TOKEN_BALANCE);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, INITIAL_TOKEN_BALANCE);
        vm.stopPrank();
        console.log(">>>>>>>>> 10");
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUSDpriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = engine.getHealthFactor(alice);

        ERC20Mock(weth).mint(liquidator, COLLATERAL_TO_COVER);
        console.log(">>>>>>>>>> 20");
        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_TO_COVER);
        engine.depositCollateralAndMintDSC(weth, COLLATERAL_TO_COVER, INITIAL_TOKEN_BALANCE);
        dsc.approve(address(engine), INITIAL_TOKEN_BALANCE);
        console.log(">>>>>> 30");
        engine.liquidate(weth, alice, INITIAL_TOKEN_BALANCE); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = engine.getTokenAmountFromUSD(weth, INITIAL_TOKEN_BALANCE)
            + (engine.getTokenAmountFromUSD(weth, INITIAL_TOKEN_BALANCE) / engine.getLiquidationBonus());
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = engine.getTokenAmountFromUSD(weth, INITIAL_TOKEN_BALANCE)
            + (engine.getTokenAmountFromUSD(weth, INITIAL_TOKEN_BALANCE) / engine.getLiquidationBonus());

        uint256 usdAmountLiquidated = engine.getUsdValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd = engine.getUsdValue(weth, COLLATERAL_AMOUNT) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = engine.getAccountInformation(alice);
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDscMinted,) = engine.getAccountInformation(liquidator);
        assertEq(liquidatorDscMinted, INITIAL_TOKEN_BALANCE);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDscMinted,) = engine.getAccountInformation(alice);
        assertEq(userDscMinted, 0);
    }

    // View & Pure Function Tests //
    function testGetCollateralTokenPriceFeed() public view {
        address priceFeed = engine.getCollateralTokenPriceFeed(weth);
        assertEq(priceFeed, ethUSDpriceFeed);
    }

    function testGetCollateralTokens() public view {
        address[] memory collateralTokens = engine.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public view {
        uint256 minHealthFactor = engine.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public view {
        uint256 liquidationThreshold = engine.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = engine.getAccountInformation(alice);
        uint256 expectedCollateralValue = engine.getUsdValue(weth, COLLATERAL_AMOUNT);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        uint256 collateralBalance = engine.getCollateralBalanceOfUser(alice, weth);
        assertEq(collateralBalance, COLLATERAL_AMOUNT);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(engine), COLLATERAL_TO_COVER);
        engine.depositCollateral(weth, COLLATERAL_TO_COVER);
        vm.stopPrank();
        uint256 collateralValue = engine.getAccountCollateralValue(alice);
        uint256 expectedCollateralValue = engine.getUsdValue(weth, COLLATERAL_TO_COVER);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetDsc() public view {
        address dscAddress = engine.getDSC();
        assertEq(dscAddress, address(dsc));
    }

    function testLiquidationPrecision() public view {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = engine.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }
}
