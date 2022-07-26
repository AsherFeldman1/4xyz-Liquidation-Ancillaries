// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Libraries/FlashLoanReceiverBase.sol";
import "./Interfaces/ILendingPool.sol";
import "./Interfaces/ILendingPoolAddressesProvider.sol";
import "./Interfaces/IOrderBook.sol";
import "./Interfaces/IFxVaults.sol";
import "./Interfaces/ILiquidator.sol";

contract Liquidator is ILiquidator, FlashLoanReceiverBase {

	using SafeMath for uint256;

	uint internal constant BONE = 1e18;

	IOrderBook orderbook;

	ILendingPoolAddressesProvider provider;

	address[] vaults;

	address internal usdc;

	constructor(address _provider, address _orderBook, address _usdc, address[] memory _vaults) FlashLoanReceiverBase(_provider) {
		orderbook = IOrderBook(_orderBook);
		provider = ILendingPoolAddressesProvider(_provider);
		usdc = _usdc;
		vaults = _vaults;
	}

	function executeOperation(address _reserve, uint _amount, uint _fee, bytes calldata _params) external override {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");

        (uint _vaultID, uint _orderBookIndex, uint _price, uint _volume) = abi.decode(_params, (uint, uint, uint, uint));

        IFxVaults vault = IFxVaults(vaults[_orderBookIndex]);

		orderbook.marketBuy(_orderBookIndex, _price, _volume);
		vault.liquidate(_vaultID);

        uint totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);
	}

	function liquidate(uint _vaultID, uint _orderBookIndex, uint _price, uint _volume) external override {
		uint usdcNeeded = _price.mul(_volume).div(BONE);
		bytes memory params = abi.encode(_vaultID, _orderBookIndex, _price, _volume);
		getFlashLoanUSDC(usdcNeeded, params);
	}

	function getFlashLoanUSDC(uint _amount, bytes memory _params) internal {
		ILendingPool pool = ILendingPool(provider.getLendingPool());
		pool.flashLoan(address(this), usdc, _amount, _params);
	}
}