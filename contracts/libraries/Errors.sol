// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library Errors {
    /* Helpers */
    error ZeroAddress();
    error ZeroAmount();

    /* OwnershipUpgradeable */
    error NotOwner();
    error NotNominee();
    error OwnerCannotBeNominee();
    error AlreadyNominee();

    /* BDT Token */
    error NotEnoughTokenToBurn();

    /* BDT Liquidity */
    error NotEnoughUSDTTokenForLiquidity();
    error NotEnoughBDTTokenForLiquidity();
    error InvalidRate();
}
