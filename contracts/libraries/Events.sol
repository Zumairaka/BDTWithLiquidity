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
     * @notice emitted when the BDT token is burnt
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
     * @notice emitted when the Liquidity is removed from the pancake swap (USDT/BDT)
     * @param amountA amount of USDT
     * @param amountB amount of BDT
     */
    event RemovedLiquidity(uint256 amountA, uint256 amountB);

    /**
     * @notice emitted when the slippage rate is modified
     * @param newSlippageRate new slippage rate
     */
    event SlippageRateModified(uint256 newSlippageRate);

    /**
     * @notice emitted when the price oracle addresses are modified
     * @param USDTOracle address of USDT oracle
     * @param BDTOracle address of BDT oracle
     */
    event PriceOraclesModified(address USDTOracle, address BDTOracle);

    /**
     * @notice emitted when the token addresses are modified
     * @param USDT address of USDT token
     * @param BDT address of BDT token
     */
    event TokenAddressesModified(address USDT, address BDT);

    /**
     * @notice emitted when the pancake router address is modified
     * @param router address of pancake router
     */
    event RouterAddressModified(address router);
}
