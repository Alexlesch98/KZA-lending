// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import "../../src/core/misc/BinanceOracle/opBNBBNBBinanceOracleAggregator.sol";
import "../../src/core/misc/BinanceOracle/opBNBBTCBinanceOracleAggregator.sol";

contract InitBinanceOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        new opBNBBNBBinanceOracleAggregator();
        new opBNBBTCBinanceOracleAggregator();

        vm.stopBroadcast();
    }
}