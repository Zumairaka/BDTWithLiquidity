// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library Events {
    /* OwnershipUpgradeable Events */
    /**
     * @notice emitted when the nominee is added
     * @param owner admin address
     * @param nominee nominee address
     */
    event NomineeAdded(address indexed owner, address indexed nominee);

    /**
     * @notice emitted when the owner is modified
     * @param newOwner new admin address
     */
    event OwnerChanged(address indexed newOwner);

    /* BDT Token Events */
    /**
     * @notice emitted when BDT token is minted
     * @param account to which minting has to be done
     * @param amount amount of token
     */
    event MintedBDTtoken(address indexed account, uint256 amount);

    /**
     * @notice emitted when the NFT is burnt
     * @param amount amount of token to be burnt
     */
    event BurntBDTtoken(uint256 amount);

    /* BDT Liquidity Events */
    /**
     * @notice emitted when the Liquidity is added to the pancake swap (USDT/BDT)
     * @param amountA amount of USDT
     * @param amountB amount of BDT
     * @param liquidity amount of LP token
     */
    event AddedLiquidity(uint256 amountA, uint256 amountB, uint256 liquidity);

    /**
     * @notice emitted when the slippage rate is modified
     * @param newSlippageRate new slippage rate
     */
    event SlippageRateModified(uint256 newSlippageRate);
}
