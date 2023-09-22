// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../helpers/OwnershipUpgradeable.sol";

/**
 * @author DigitalTrustCSP
 * @dev This contract is for minting BlueDiamondTokens(BDT).
 */
contract BlueDiamondToken is ERC20Upgradeable, OwnershipUpgradeable {
    /* Public Functions */
    /**
     * @notice this function is for initializing the contract
     * @dev set the token name, symbol and initial supply
     */
    function initialize() public initializer {
        __Ownership_init();
        __ERC20_init("Blue Diamond Token", "BDT");

        // mint tokens
        _mint(msg.sender, 7000000 * 10 ** uint256(decimals()));
    }

    /* External Functions */
    /**
     * @notice function for minting the new BDT tokens
     * @dev only owner can mint tokens
     * @param account_ account address to which the token has to be minted
     * @param amount_ amount of tokens to be minted
     */
    function mint(address account_, uint256 amount_) public onlyOwner {
        Helpers._checkAddress(account_);
        Helpers._checkAmount(amount_);

        // mint tokens to the account
        emit Events.MintedBDTtoken(account_, amount_);

        _mint(account_, amount_);
    }

    /**
     * @notice function for burning the BDT tokens
     * @dev only owner can burn tokens
     * @param amount_ amount of tokens to be burnt
     */
    function burn(uint256 amount_) public onlyOwner {
        Helpers._checkAmount(amount_);

        // check balance
        if (balanceOf(msg.sender) < amount_) {
            revert Errors.NotEnoughTokenToBurn();
        }

        // burn tokens
        emit Events.BurntBDTtoken(amount_);

        _burn(msg.sender, amount_);
    }
}
