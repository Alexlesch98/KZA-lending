// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import "../../src/core/deployments/ReservesSetupHelper.sol";
import "../../src/core/protocol/configuration/ACLManager.sol";
import "../../src/core/protocol/pool/PoolConfigurator.sol";
import "../../src/core/interfaces/IPoolAddressesProvider.sol";

contract setupRiskParameter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address provider = vm.envAddress("PoolAddressesProvider");
        address aclAddress = vm.envAddress("ACLManager");
        address helperAddr = vm.envAddress("ReservesSetupHelper");
        vm.startBroadcast(deployerPrivateKey);

        ReservesSetupHelper helper = ReservesSetupHelper(helperAddr);
        //add helper to pool admin
        ACLManager acl = ACLManager(aclAddress);
        acl.addPoolAdmin(address(helper));

        PoolConfigurator configurator = PoolConfigurator(IPoolAddressesProvider(provider).getPoolConfigurator());
        ReservesSetupHelper.ConfigureReserveInput[] memory inputs = new ReservesSetupHelper.ConfigureReserveInput[](1);
        string[] memory tokens = new string[](1);
        tokens[0] = "SMART_LP_HAY";
        // tokens[1] = "SMART_LP_USDC";
        // tokens[2] = "SMART_LP_USDT";
        address token;
        for (uint256 i; i < tokens.length; i++) {
            token =  vm.envAddress(tokens[i]);

            inputs[i] = ReservesSetupHelper.ConfigureReserveInput(
                token,
                vm.envUint(string(abi.encodePacked(tokens[i], "_BASE_LTV"))),
                vm.envUint(string(abi.encodePacked(tokens[i], "_BASE_LIQUDATION_THRESHOLD"))),
                vm.envUint(string(abi.encodePacked(tokens[i], "_BASE_LIQUDATION_BONUS"))),
                vm.envUint(string(abi.encodePacked(tokens[i], "_RESERVE_FACTOR"))),
                vm.envUint(string(abi.encodePacked(tokens[i], "_BORROW_CAP"))),
                vm.envUint(string(abi.encodePacked(tokens[i], "_SUPPLY_CAP"))),
                vm.envBool(string(abi.encodePacked(tokens[i], "_STABLE_BORROWING_ENABLED"))),
                vm.envBool(string(abi.encodePacked(tokens[i], "_BORROWING_ENABLED"))),
                vm.envBool(string(abi.encodePacked(tokens[i], "_FLASHLOAN_ENABLED")))
                );
        }

        helper.configureReserves(configurator, inputs);

        //remove helper from pool admin
        acl.removePoolAdmin(address(helper));
        vm.stopBroadcast();
    }
}
