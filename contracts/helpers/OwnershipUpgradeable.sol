// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {Helpers} from "../libraries/Helpers.sol";

/**
 * @author DigitalTrustCSP
 * @notice this contract is used instead of Ownable contract
 * from openzeppelin. This will ensure the ownership is not
 * accidently transferred to zero address or other false addresses.
 */

contract OwnershipUpgradeable is Initializable {
    /* State Variables */
    address private _owner;
    address private _nominee;

    /* Modifiers */
    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert Errors.NotOwner();
        }
        _;
    }

    /* Public Functions */
    /**
     * @dev returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev returns the address of the current nominee.
     */
    function nominee() public view virtual returns (address) {
        return _nominee;
    }

    /* Owner Functions */
    /**
     * @notice function for adding a nominee
     * @dev this nominee can be the next owner upon accepting the ownership
     * @dev only owner can add this nominee
     * @dev owner can revoke nomination by sending zero address
     * @dev owner cannot be a nominee
     * @param account nominee address
     */
    function addNominee(address account) public onlyOwner {
        if (_owner == account) {
            revert Errors.OwnerCannotBeNominee();
        }
        if (_nominee == account) {
            revert Errors.AlreadyNominee();
        }

        emit Events.NomineeAdded(msg.sender, account);
        _nominee = account;
    }

    /**
     * @notice function for accepting the nomination
     * @dev only the nominee can call this function
     * @dev the ownership will be transferred
     * @dev emits an event OwnerChanged
     */
    function acceptNomination() public {
        if (msg.sender != _nominee) {
            revert Errors.NotNominee();
        }

        emit Events.OwnerChanged(msg.sender);
        _owner = msg.sender;
        _nominee = address(0);
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownership_init() internal onlyInitializing {
        Helpers._checkAddress(msg.sender);

        emit Events.OwnerChanged(msg.sender);
        _owner = msg.sender;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
