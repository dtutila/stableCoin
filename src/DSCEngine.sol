// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title DSCEngine 
contract DSCEngine is ReentrancyGuard{
  
  //errors

  error DSCEngine__AmountMustBeGreaterThanZero();
  error DSCEngine__TokenAddressessAndPriceFeedAddressesMustBeSameLength(); 
  error DSCEngine__TokenNotAllowed();

  // state vars
  mapping(address token => address priceFeed) private s_priceFeed;
  mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

  DecentralizedStableCoin private immutable i_dsc;

  event DSCEngine__CollateralDeposited(address indexed user, address token, uint256 amount);

  //modifiers
  modifier moreThanZero(uint256 _amount) {
    if (_amount <= 0) {
      revert DSCEngine__AmountMustBeGreaterThanZero();
    }

    _;
  }

  modifier isAllowedToken(address token) {
    if (s_priceFeed[token] == address(0)) {
      revert DSCEngine__TokenNotAllowed();
    }
    _;
  }

  constructor (
      address[] memory _tokenAddresses,
      address[] memory _priceFeedAddresses,
      address _dscAddress
  ) {
    if (_tokenAddresses.length != _priceFeedAddresses.length) {
      revert DSCEngine__TokenAddressessAndPriceFeedAddressesMustBeSameLength();
    }

    i_dsc = DecentralizedStableCoin(_dscAddress);

    for (uint256 i = 0; i < _tokenAddresses.length; i++) {
      s_priceFeed[_tokenAddresses[i]] = _priceFeedAddresses[i];      
    }

  }


  //external functions
  function depositCollateralAndMintDSC() external {}
  
  function depositCollateral(
      address _collateralAddress,
      uint256 _amount) 
    external 
    moreThanZero(_amount) 
    isAllowedToken(_collateralAddress)
    nonReentrant()
  {
    s_collateralDeposited[msg.sender][_collateralAddress] += _amount;
    emit DSCEngine__CollateralDeposited(msg.sender, _collateralAddress,_amount);
    

    

  }
  
  function redeemColateralForDSC() external {}
  
  function redeemColateral() external {}

  function mintDSC() external {}
  function burnDSC() external {}
  function liquidate() external {}
  function healthFactor() external view {}

 
}
