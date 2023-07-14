// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';

import '../../core/interfaces/IPoolAddressesProvider.sol';
import '../../core/interfaces/IPool.sol';
import '../../core/interfaces/IPoolDataProvider.sol';
import '../../core/interfaces/IAaveOracle.sol';
import '../../core/protocol/libraries/types/DataTypes.sol';

/**
 * @title EmodeBorrowableData contract
 * @author Kinza
 * @notice Implements a logic of getting max borrowable for a particular account
 * @dev NOTE: THIS CONTRACT IS NOT USED WITHIN THE LENDING PROTOCOL. It's an accessory contract used to reduce the number of calls
 * towards the blockchain from the backend.
 **/

 interface IRouter {
    function swapExactTokensForTokens(
            uint256 amounIn, 
            uint256 amountOutMin, 
            address[] memory path, 
            address to) 
            external payable;
    function factory() external view returns(address);
    function factoryV2() external view returns(address);
 }

 interface IFactory {
    function getPool(address, address, uint256) external view returns(address);
 }
 interface IFactory2 {
    function getPair(address, address) external view returns(address);
 }

contract LiquidationAdaptor {
    address constant public ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant public WBETH = 0xa2E3356610840701BDf5611a53974510Ae27E2e1;
    address constant public WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant public BTC = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant public USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant public BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant public USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address constant public TUSD = 0x40af3827F39D0EAcBF4A168f8D4ee67c121D11c9;

    address constant public router = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
    // this struct for getting away with "stack too depp"
    struct UserReserve{
        uint256 currentATokenBalance;
        uint256 currentStableDebt;
        uint256 currentVariableDebt;
        bool usageAsCollateralEnabled;
    }
    // result from the liquidation check
    struct LiquidationCheckResult {
        bool isLiquidable;
        address MostValuableCollateral;
        address MostValuableDebt;
        uint256 CollateralPrice;
        uint256 DebtPrice;
        uint256 CollateralAmountSeizable;
        uint256 DebtAmountRepayable;
    }

    uint256 internal constant HEALTH_THRESHOLD = 1 * 10 ** 18;

    IPoolAddressesProvider immutable public provider;

    modifier onlyPool() {
        require(msg.sender == provider.getPool());
        _;
    }
    constructor(address _provider) {
        provider = IPoolAddressesProvider(_provider);
    }
    
    function getUserReserveData(address token, address user) public view returns(UserReserve memory r) {
        IPoolDataProvider dataProvider = IPoolDataProvider(provider.getPoolDataProvider());
        (uint256 currentATokenBalance, 
        uint256 currentStableDebt,
        uint256 currentVariableDebt,,,,,,
        bool usageAsCollateralEnabled) = dataProvider.getUserReserveData(token, user);
        r.currentATokenBalance = currentATokenBalance;
        r.currentStableDebt  = currentStableDebt;
        r.currentVariableDebt = currentVariableDebt;
        r.usageAsCollateralEnabled = usageAsCollateralEnabled;
    }
    function getUsersHealth(address[] memory users) public view returns(LiquidationCheckResult[] memory) {
            IPoolDataProvider dataProvider = IPoolDataProvider(provider.getPoolDataProvider());
            IPool pool = IPool(provider.getPool());
            LiquidationCheckResult[] memory result = new LiquidationCheckResult[](users.length);
            for (uint256 i; i < users.length;i++) {
                LiquidationCheckResult memory r;
                (,,,,,uint256 healthFactor) = pool.getUserAccountData(users[i]);
                if (healthFactor >= HEALTH_THRESHOLD) {
                    result[i] = r;
                } else {
                    // user is subject to liqidation
                    // loop each asset to find user's most worthy aToken/debtToken
                    r.isLiquidable = true;
                    IPoolDataProvider.TokenData[] memory tokens = dataProvider.getAllReservesTokens();
                    for (uint256 j;j<tokens.length;j++) {
                        UserReserve memory reserveData = getUserReserveData(tokens[j].tokenAddress, users[i]);
                        uint256 price = getAssetPrice(tokens[j].tokenAddress);
                        if (r.CollateralPrice * r.CollateralAmountSeizable < reserveData.currentATokenBalance * price && reserveData.usageAsCollateralEnabled) {
                            r.CollateralAmountSeizable = reserveData.currentATokenBalance;
                            r.MostValuableCollateral = tokens[j].tokenAddress;
                            r.CollateralPrice = price;
                        }
                        // over-estimate of debtAmountToRepay
                        // dummpy algorithm, not smart but more readable aim for off-chain purposes
                        if (r.DebtAmountRepayable * r.DebtPrice < (reserveData.currentStableDebt + reserveData.currentVariableDebt) * price) {
                            r.MostValuableDebt = tokens[j].tokenAddress;
                            r.DebtPrice = price;
                            r.DebtAmountRepayable = reserveData.currentStableDebt + reserveData.currentVariableDebt;
                        }
                    }
                    // minimum of close factor(0.5) or the amount equivalent to the most valuable collateral to seize
                    r.DebtAmountRepayable = r.DebtAmountRepayable / 2 > r.CollateralPrice * r.CollateralAmountSeizable / r.DebtPrice ?
                                            r.CollateralPrice * r.CollateralAmountSeizable / r.DebtPrice :
                                            r.DebtAmountRepayable / 2;
                    // base on the DebtAmountRepayable, update the collateral to seize
                    r.CollateralAmountSeizable = r.DebtAmountRepayable * r.DebtPrice / r.CollateralPrice;
                    result[i] = r;
                    
                }
            }
            return result;
    }

    function getAssetPrice(address asset) public view returns(uint256) {
        IPoolDataProvider dataProvider = IPoolDataProvider(provider.getPoolDataProvider());
        IAaveOracle oracle = IAaveOracle(provider.getPriceOracle());
        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256[] memory prices = oracle.getAssetsPrices(assets);
        uint256 price = prices[0];
        return price;
    }

    // call this to liquidate a user
    function liquidateWithFlashLoan(address liquidated, address collateral, address debtToken, uint256 debtAmount) external {
        IPoolDataProvider dataProvider = IPoolDataProvider(provider.getPoolDataProvider());
        IPool pool = IPool(provider.getPool());
        // allow the pool to get back the flashloan + premium
        IERC20(debtToken).approve(address(pool), type(uint256).max);
        //construct calldata to be execute in "executeOperation
        bytes memory params = abi.encode(collateral, liquidated, msg.sender);
        pool.flashLoanSimple(
            address(this),
            debtToken,
            debtAmount,
            params,
            0
        );
    }

    function executeOperation(
    address borrowedAsset,
    uint256 amount,
    uint256 premium,
    address, //initiator, which would be this address if called from liquidateWithFlashLoan
    bytes memory params
  )  external onlyPool returns (bool){
        // 1. repay for the liquidated user using the flashloan amount
        (address collateralAsset, address liquidatedUser, address liquidator) = abi.decode(params, (address, address, address));
        IPool pool = IPool(provider.getPool());
        pool.liquidationCall(
            collateralAsset,
            borrowedAsset,
            liquidatedUser,
            amount,
            // receiveAToken
            false
            );
        uint256 seizedCollateralAmount = IERC20(collateralAsset).balanceOf(address(this));
        if (collateralAsset != borrowedAsset) {
            uint256 seizedCollateralAmount = IERC20(collateralAsset).balanceOf(address(this));
            // 2. swap the collateral back to the debtToken
            // approve the router for pulling the tokeIn
            IERC20(collateralAsset).approve(address(router), type(uint256).max);
            _swap(collateralAsset, borrowedAsset, seizedCollateralAmount);
        }
        // 3. set aside the flashloan amount + premium for repay
        // minus 1 wei more for any (potential) floor down
        uint256 profit = IERC20(borrowedAsset).balanceOf(address(this)) - amount - premium - 1;
        // 4. send any profit to msg.sender
        IERC20(borrowedAsset).transfer(liquidator, profit);
        return true;
    }

    // this function takes tokenIn and return tokenOut,
    // by swapping tokenIn -> BNB, then BNB -> tokenOut;

    function _swap(address _tokenIn, address _tokenOut, uint256 _amountIn) internal {
        address[] memory path;
        path = _pathGenerator(_tokenIn, _tokenOut);
        IRouter(router).swapExactTokensForTokens(_amountIn, 0, path, address(this));
    }

    function _pathGenerator(address _tokenIn, address _tokenOut) internal view returns (address[] memory) {
        
        address[] memory path; 
        // hide direct pool since some of them has less liquidity (TUSD -> WBNB etc)
        // if (IFactory2(IRouter(router).factoryV2()).getPair(_tokenIn, _tokenOut) != address(0) || 
        //     IFactory(IRouter(router).factory()).getPool(_tokenIn, _tokenOut, 10000) != address(0) ||
        //     IFactory(IRouter(router).factory()).getPool(_tokenIn, _tokenOut, 2500) != address(0) ||
        //     IFactory(IRouter(router).factory()).getPool(_tokenIn, _tokenOut, 500) != address(0) ||
        //     IFactory(IRouter(router).factory()).getPool(_tokenIn, _tokenOut, 100) != address(0)
        //     ) {
        //         // exact pool exists
        //         path = new address[](2);
        //         path[0] = _tokenIn;
        //         path[1] = _tokenOut;
        //         return path;
        //     }
        // use hard-coded path;
        // 5 is the max length to swap to WBNB as the intermediate
        address[] memory tmp_path = new address[](5);
        uint256 length;
        if (_tokenIn == BTC) {
            tmp_path[length] == BTC;
            tmp_path[length+1] == WBNB;
            length+=2;
        }

        if (_tokenIn == ETH) {
            tmp_path[length] == ETH;
            tmp_path[length+1] == WBNB;
            length+=2;
        }

        if (_tokenIn == WBNB) {
            tmp_path[length] == WBNB;
            length++;
        }
        if (_tokenIn == USDC) {
            tmp_path[length] == USDC;
            tmp_path[length+1] == BUSD;
            tmp_path[length+2] == WBNB;
            length += 3;
        }
        if (_tokenIn == TUSD) {
            tmp_path[length] == TUSD;
            tmp_path[length+1] == USDT;
            tmp_path[length+2] == WBNB;
            length += 3;
        }
        if (_tokenIn == USDT) {
            tmp_path[length] == USDT;
            tmp_path[length+1] == WBNB;
            length += 2;
        }
        if (_tokenIn == BUSD) {
            tmp_path[length] == BUSD;
            tmp_path[length+1] == WBNB;
            length += 2;
        }
        if (_tokenIn == WBETH) {
            path[0] = WBETH;
            path[1] = ETH;
            path[2] = WBNB;
            path[3] = _tokenOut;
        } else {
            path[0] = _tokenIn;
            path[1] = WBNB;
            path[2] = ETH;
            path[3] = WBETH;
            tmp_path[length] = WBETH;
            tmp_path[length+1] = ETH;
            tmp_path[length+2] = WBNB;
            length += 2;
        }

        // output
        if (_tokenOut == ETH) {
            tmp_path[length] == ETH;
            length++;
        }
        if (_tokenOut == WBNB) {
            // do nothing
        }
        if (_tokenOut == USDC) {
            tmp_path[length] == BUSD;
            tmp_path[length+1] == USDC;
            length += 2;
        }
        if (_tokenOut == TUSD) {
            tmp_path[length] == USDT;
            tmp_path[length+1] == TUSD;
            length += 2;
        }
        if (_tokenOut == USDT) {
            tmp_path[length] == USDT;
            length += 1;
        }
        if (_tokenOut == BUSD) {
            tmp_path[length] == BUSD;
            length += 1;
        }
        if (_tokenOut == WBETH) {
            tmp_path[length] = ETH;
            tmp_path[length+1] = WBETH;
            length += 2;
        }
        path = new address[](length);
        for (uint256 i;i < length;i++) {
            path[i] = tmp_path[i];
        }
        return path;
    }
}