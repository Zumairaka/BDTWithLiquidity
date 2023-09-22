// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Errors} from "./Errors.sol";

library Helpers {
    /**
     * @notice function to check if the address is zero address
     * @param account_ account address which has to be tested
     */
    function _checkAddress(address account_) internal pure {
        if (account_ == address(0)) {
            revert Errors.ZeroAddress();
        }
    }

    /**
     * @notice function to check if the amount is zero
     * @param amount_ amount
     */
    function _checkAmount(uint256 amount_) internal pure {
        if (amount_ == 0) {
            revert Errors.ZeroAmount();
        }
    }
}
