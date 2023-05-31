// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import "../../src/core/mocks/flashloan/MockFlashLoanReceiver.sol";

contract DeployMockFlashLoanReceveiver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address provider = vm.envAddress("PoolAddressesProvider");
        vm.startBroadcast(deployerPrivateKey);

        new MockFlashLoanReceiver(
                IPoolAddressesProvider(provider)
        );
        vm.stopBroadcast();

        
    }
}