// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";


contract Handler is Test {
  DSCEngine engine;
  DecentralizedStableCoin dsc;
  ERC20Mock weth;
  ERC20Mock wbtc;

  uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max;
  address[] public usersWithCollateralDeposited;


  constructor (DSCEngine _engine, DecentralizedStableCoin _dsc) {
    engine = _engine;
    dsc = _dsc;

    address[] memory collateralTokens = engine.getCollateralTokens();
    weth = ERC20Mock(collateralTokens[0]);
    wbtc = ERC20Mock(collateralTokens[1]);
      
  }


  function mintDSC(uint256 amount, uint256 addressSeed) public {
    vm.assume(usersWithCollateralDeposited.length > 0);
    address sender = usersWithCollateralDeposited[addressSeed %  usersWithCollateralDeposited.length];
    (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(sender);
    int256 maxDSCToMint = (int256(collateralValueInUSD)/2) - int256(totalDSCMinted);
    vm.assume(maxDSCToMint > 0);
    amount = bound(amount, 1, uint256(maxDSCToMint));

    vm.startPrank(sender);
    engine.mintDSC(amount);

    vm.stopPrank();
    
  }



  function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
    vm.startPrank(msg.sender);
    collateral.mint(msg.sender, amountCollateral);
    collateral.approve(address(engine), amountCollateral);
    engine.depositCollateral(address(collateral), amountCollateral);
    vm.stopPrank();
    usersWithCollateralDeposited.push(msg.sender);
  }

   function redeemCollareral(uint256 collateralSeed, uint256 amountCollateral) public {
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    uint256 maxCollateralToReedem = engine.getCollateralBalanceOfUser(address(collateral), msg.sender);
    vm.assume(maxCollateralToReedem > 0);
    amountCollateral = bound(amountCollateral, 1, maxCollateralToReedem);
    engine.redeemColateral(address(collateral), amountCollateral);
  }

  // function mintDSC(uint256 amount, uint256 addressSeed) public {
  //   vm.assume(usersWithCollateralDeposited.length > 0);
  //   address sender = usersWithCollateralDeposited[addressSeed %  usersWithCollateralDeposited.length];
  //   (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(sender);
  //   int256 maxDSCToMint = (int256(collateralValueInUSD)/2) - int256(totalDSCMinted);
  //   vm.assume(maxDSCToMint > 0);
  //   amount = bound(amount, 0, uint256(maxDSCToMint));
  //
  //   vm.startPrank(sender);
  //   engine.mintDSC(amount);
  //
  //   vm.stopPrank();
  //   
  // }

  //helpers
  
  function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
    if (collateralSeed % 2 == 0) {
      return weth;
    }
    return wbtc;

  }
}
