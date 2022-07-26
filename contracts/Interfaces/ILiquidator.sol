// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILiquidator {
	function liquidate(uint _vaultID, uint _orderBookIndex, uint _price, uint _volume) external;
}