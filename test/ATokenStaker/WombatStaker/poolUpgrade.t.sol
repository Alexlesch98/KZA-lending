
import {ATokenWombatStakerBaseTest} from "./ATokenWombatStakerBaseTest.t.sol";
import {IERC20} from "../../../src/core/dependencies/openzeppelin/contracts/IERC20.sol";
import {ValidationLogic} from "../../../src/core/protocol/libraries/logic/ValidationLogic.sol";
import {IPoolAddressesProvider} from "../../../src/core/interfaces/IPoolAddressesProvider.sol";
import {Pool} from "../../../src/core/protocol/pool/Pool.sol";

import {TIMELOCK, ADDRESSES_PROVIDER, POOLDATA_PROVIDER, ACL_MANAGER, POOL, POOL_CONFIGURATOR, EMISSION_MANAGER, 
        ATOKENIMPL, SDTOKENIMPL, VDTOKENIMPL, TREASURY, POOL_ADMIN, HAY_AGGREGATOR, HAY, 
        MASTER_WOMBAT, SMART_HAY_LP, LIQUIDATION_ADAPTOR, BORROWABLE_DATA_PROVIDER} from "test/utils/Addresses.sol";

// @dev disable linked lib in foundry.toml, since forge test would inherit those setting
// https://book.getfoundry.sh/reference/forge/forge-build?highlight=link#linker-options
contract poolUpgradeTest is ATokenWombatStakerBaseTest {

    function setUp() public virtual override(ATokenWombatStakerBaseTest) {
        ATokenWombatStakerBaseTest.setUp();
        // deploy new pool impl with new validationLogic
        
        Pool poolV2 = new Pool(IPoolAddressesProvider(ADDRESSES_PROVIDER));
        poolV2.initialize(IPoolAddressesProvider(ADDRESSES_PROVIDER));
        // upgrade
        vm.startPrank(TIMELOCK);
        provider.setPoolImpl(address(poolV2));
        assertEq(Pool(address(pool)).POOL_REVISION(), 0x2);
    }

    function test_enableCollateralWithZeroLTV() public {
        setReserveAsZeroLTV();
        address bob = address(1);
        turnOnEmode(bob);
        deposit(bob, 1e18, underlying);
        turnOnCollateral(bob, underlying);
    }

    function setReserveAsZeroLTV() internal {
        vm.startPrank(POOL_ADMIN);
        configurator.configureReserveAsCollateral(underlying, 0, 0, 0);
    }

}