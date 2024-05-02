// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";


contract DeployDSC is Script {

  function run() external returns (DecentralizedStableCoin, DSCEngine) {

    vm.startBroadcast();
    DecentralizedStableCoin dsc = new DecentralizedStableCoin();

    DSCEngine engine = new DSCEngine();

    vm.stopBroadcast();
    
  }
  
}