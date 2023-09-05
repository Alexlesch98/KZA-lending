
import {ATokenWombatStakerBaseTest} from "./ATokenWombatStakerBaseTest.t.sol";
import {IERC20} from "../../../src/core/dependencies/openzeppelin/contracts/IERC20.sol";
import {ADDRESSES_PROVIDER, POOLDATA_PROVIDER, ACL_MANAGER, POOL, POOL_CONFIGURATOR, EMISSION_MANAGER, 
        ATOKENIMPL, SDTOKENIMPL, VDTOKENIMPL, TREASURY, POOL_ADMIN, HAY_AGGREGATOR, HAY, 
        MASTER_WOMBAT, SMART_HAY_LP, LIQUIDATION_ADAPTOR} from "test/utils/Addresses.sol";

contract unitTest is ATokenWombatStakerBaseTest {

    function setUp() public virtual override(ATokenWombatStakerBaseTest) {
        ATokenWombatStakerBaseTest.setUp();
    }

    function test_deposit() public {
        address bob = address(1);
        uint256 amount = 1 ether;
        deposit(bob, amount, underlying);
    }

    function test_withdraw() public {
        address bob = address(1);
        uint256 amount = 1 ether;
        deposit(bob, amount, underlying);
        withdraw(bob, amount, underlying);
    }

    function test_borrowWhenBorrowDisabled() public {
        address bob = address(1);
        uint256 collateralAmount = 100_000;
        uint256 borrow_amount = 100;
        prepUSDC(bob, collateralAmount);
        //when borrow is disabled
        borrowExpectFail(bob, borrow_amount, underlying, '30');
    }
    function test_borrowWhenBorrowEnabled() public {
        address bob = address(1);
        uint256 collateralAmount = 100_000 * 1e18;
        uint256 borrow_amount = 100 * 1e18;
        // have a deposit first, so there is reserve available
        deposit(bob, borrow_amount, underlying);
        prepUSDC(bob, collateralAmount);
        turnOnBorrow();
        borrowExpectFail(bob, borrow_amount, underlying, 'ATokenStaker does not allow flashloan or borrow');
    }

    function test_borrowWhenBorrowEnabledNonZeroPrice() public {
        address bob = address(1);
        uint256 collateralAmount = 100_000 * 1e18;
        uint256 borrow_amount = 100 * 1e18;
        // have a deposit first, so there is reserve available
        deposit(bob, borrow_amount, underlying);
        prepUSDC(bob, collateralAmount);
        turnOnBorrow();
        // this is a set-up to test the error, in mainnet we wont set price for LP
        setUpOracle(HAY_AGGREGATOR, underlying);
        //when borrow is enabled, price is non-zero borrow is reverted by AToken
        borrowExpectFail(bob, borrow_amount, underlying, 'ATokenStaker does not allow flashloan or borrow');
    }


    function test_flashloanWhenDisabled() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        flashloanRevert(bob, collateralAmount, underlying, '91');
    }

     function test_flashloanWhenEnabled() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        turnOnFlashloan();
        deposit(bob, collateralAmount, underlying);
        flashloanRevert(bob, collateralAmount, underlying, 'ATokenStaker does not allow flashloan or borrow');
    }

    function test_enableAsCollateralRevert() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        // 62 is ltv is 0
        turnOnCollateralExpectRevert(bob, underlying, '62');
    }

    function test_disableAsCollateral() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        turnOffCollateral(bob, underlying);
    }

    // liquidate
    function test_liquidateRevertOutsideEmode() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        turnOnCollateral(bob, underlying);
        // now setup a bad debt
        prepUSDC(bob, 1e18);
        address debtAsset = HAY;
        borrow(bob, 6e17, debtAsset);
        // pass 100y
        vm.warp(36500 days);
        // verify health factor < 1;
        (,,,,, uint256 healthFactor) = pool.getUserAccountData(bob);
        assertLt(healthFactor, 1e18);
        // attempt to liquidate half of original debt
        liquidateRevert(bob, debtAsset, underlying, 3e17);

    }
    function test_liquidateInsideEmode() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        turnOnEmode(bob);
        turnOnCollateral(bob, underlying);
        address debtAsset = HAY;
        uint256 debtAmount = collateralAmount / 2;
        borrow(bob, debtAmount, debtAsset);
        // pass 100y
        vm.warp(36500 days);
        // verify health factor < 1;
        (,,,,, uint256 healthFactor) = pool.getUserAccountData(bob);
        assertLt(healthFactor, 1e18);
        // attempt to liquidate half of original debt
        liquidate(bob, debtAsset, underlying, debtAmount / 2);
        // assert some collateral are seize
        assertLt(IERC20(ATokenProxyStaker).balanceOf(bob), collateralAmount);

    }
    // testEmode
    function test_enableEmode() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        turnOnEmode(bob);
    }

    function test_disableEmode() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        turnOnEmode(bob);
        turnOffEmode(bob);
    }

    function test_borrowWithEmode() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        turnOnEmode(bob);
        turnOnCollateral(bob, underlying);
        // borrow
        uint256 borrowAmount = collateralAmount / 2;
        borrow(bob, borrowAmount, HAY);
    }

    function test_flashLoanRevertWithEmode() public {
        address bob = address(1);
        uint256 collateralAmount = 100 * 1e18;
        deposit(bob, collateralAmount, underlying);
        turnOnEmode(bob);
        turnOnCollateral(bob, underlying);
        flashloanRevert(bob, collateralAmount, underlying, '91');
    }

}