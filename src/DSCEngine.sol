// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/// @title DSCEngine 
contract DSCEngine is ReentrancyGuard{
  
  //errors

  error DSCEngine__AmountMustBeGreaterThanZero();
  error DSCEngine__TokenAddressessAndPriceFeedAddressesMustBeSameLength(); 
  error DSCEngine__TokenNotAllowed();
  error DSCEngine__TransferFailed();

  uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
  uint256 private constant PRECISION = 1e18;
  // state vars
  mapping(address token => address priceFeed) private s_priceFeeds;
  mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
  mapping (address user => uint256 amountDSCMinted) s_DSCMinted;
  address[] private s_collateralTokens;


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
    if (s_priceFeeds[token] == address(0)) {
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
      s_priceFeeds[_tokenAddresses[i]] = _priceFeedAddresses[i];     
      s_collateralTokens.push(_tokenAddresses[i]);
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
    
    bool success = IERC20(_collateralAddress).transferFrom(msg.sender, address(this), _amount);
    if (!success) {
      revert DSCEngine__TransferFailed();
    }
    

  }
  
  function redeemColateralForDSC() external {}
  
  function redeemColateral() external {}

  function mintDSC(uint256 _amountDSCToMint) external {
    s_DSCMinted[msg.sender] += _amountDSCToMint;
    //check heatlh
    _revertIfHealthFactorIsBroken(msg.sender);


  }

  function burnDSC() external {}
  function liquidate() external {}
  function healthFactor() external view {}

  //internal functions

  function _getAccountInformation(address user) private view returns (uint256, uint256){
    uint256 totalDSCMinted = s_DSCMinted[user];
    uint256 collateralValueInUSD = getAccountCollateralValue(user);

  }

  function _healthFactor(address user) private view returns (uint256) {
    (uint256 totalDSCMinted, uint256 collateralValueInUSD) = 
      _getAccountInformation(user);
  }

  function _revertIfHealthFactorIsBroken(address user) internal view {

  }

  //public and external view functions

  function getAccountCollateralValue(address user) public view returns (uint256) {
    uint256 totalValue;
    for (uint256 i = 0; i < s_collateralTokens.length; i++) {
      address token = s_collateralTokens[i];
      uint256 amount = s_collateralDeposited[user][token];
    }

    return totalValue;
  }

  function getUsdValue(address token, uint256 amount) public view returns (uint256) {
    AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
    (, int256 price,,,) = priceFeed.latestRoundData();

    return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
  }
}
