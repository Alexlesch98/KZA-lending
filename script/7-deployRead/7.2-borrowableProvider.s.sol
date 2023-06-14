// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import "../../src/core/interfaces/IPoolConfigurator.sol";
import "../../src/periphery/misc/EmodeBorrowableDataProvider.sol";

contract deployBorrowableDataProvider is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address provider = vm.envAddress("PoolAddressesProvider");
        vm.startBroadcast(deployerPrivateKey);

        new EmodeBorrowableDataProvider(provider);
        
        vm.stopBroadcast();
    }
}
