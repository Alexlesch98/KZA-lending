// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import "../../src/core/misc/ZeroReserveInterestRateStrategy.sol";
import "../../src/core/interfaces/IPoolAddressesProvider.sol";
contract deployZeroInterestStrategy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address provider = vm.envAddress("PoolAddressesProvider");
        vm.startBroadcast(deployerPrivateKey);
        new ZeroReserveInterestRateStrategy(IPoolAddressesProvider(provider));
        vm.stopBroadcast();

    }
}