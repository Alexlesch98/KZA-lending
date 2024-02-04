// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../protocol/tokenization/AToken.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IPoolAddressesProvider.sol";
import "../interfaces/IPoolConfigurator.sol";
import "../interfaces/IPoolDataProvider.sol";
import "../dependencies/openzeppelin/contracts/IERC20Detailed.sol";
import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';

/**
 * @title ReservesSetupHelper
 * @author Aave
 * @notice Deployment helper to setup the assets risk parameters at PoolConfigurator in batch.
 * @dev The ReservesSetupHelper is an Ownable contract, so only the deployer or future owners can call this contract.
 */
contract ATokenSetupHelper is Ownable {

    AToken immutable public aTokenImpl;
    address immutable public provider;

  /**
   * @notice External function called by the owner account to setup the assets risk parameters in batch.
   * @dev The Pool or Risk admin must transfer the ownership to ReservesSetupHelper before calling this function
   * @param provider The address of Addressprovider contract
   * @param treasury The address of the new treasury
   */

  constructor(address _provider) {
    IPool pool = IPool(IPoolAddressesProvider(_provider).getPool());
    aTokenImpl = new AToken(pool);
    address provider = _provider;
    // initialize the impl itself
    aTokenImpl.initialize(
        pool,
        address(0), // treasury
        address(0), // underlyingAsset
        IAaveIncentivesController(address(0)), // incentivesController
        0, // aTokenDecimals
        "ATOKEN_IMPL", // aTokenName
        "ATOKEN_IMPL", // aTokenSymbol
        "0x00" // param
    );
  }
  function updateATokensTreasury( 
    address treasury,
    address[] memory reserves
  ) external onlyOwner {
        IPoolConfigurator configurator = IPoolConfigurator(IPoolAddressesProvider(provider).getPoolConfigurator());
        IPoolDataProvider dataProvider = IPoolDataProvider(IPoolAddressesProvider(provider).getPoolDataProvider());

        bytes32 incentivesControllerId = 0x703c2c8634bed68d98c029c18f310e7f7ec0e5d6342c590190b3cb8b3ba54532;
        address controllerProxy = IPoolAddressesProvider(provider).getAddress(incentivesControllerId);
        // deploy new aToken first, then initialize it with new parameter
        
        ConfiguratorInputTypes.UpdateATokenInput memory input;
        for (uint i;i< reserves.length;i++) {
            address tokenAddress = reserves[i];
            input.asset = tokenAddress;
            input.treasury = treasury;
            input.incentivesController = controllerProxy;
            input.name = string(abi.encodePacked("Kinza", IERC20Detailed(tokenAddress).name()));
            input.symbol = string(abi.encodePacked("k", IERC20Detailed(tokenAddress).symbol()));
            input.implementation = address(aTokenImpl);
            input.params = abi.encodePacked("0x10");
            configurator.updateAToken(input);
        }   
    }
}
