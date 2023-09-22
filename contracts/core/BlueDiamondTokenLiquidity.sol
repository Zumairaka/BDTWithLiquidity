// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @author Digital Trust CSP
 * @notice Contract for managing liquidity for the pair USDT/BDT in pancake swap
 * @dev first time liquidity is added as per the price range of 1USDT/1BDT
 * @dev remaining liquidity is added by fetching the current price from chainlink oracle
 * @dev
 */

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../helpers/OwnershipUpgradeable.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter01.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/AggregatorV3Interface.sol";

contract BlueDiamondTokenLiquidity is
    ReentrancyGuardUpgradeable,
    OwnershipUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* State Varialbes */
    address private USDT; // 0x5bDD51572354BB72470Ff98f6428B12EEf3DC26f, USDT address in BSC testnet
    address private BDT;
    address private PANCAKESWAP_V2_ROUTER; // 0xD99D1c33F9fC3444f8101754aBC46c52416550D1 (testnet); 0x10ED43C718714eb63d5aA57B78B54704E256024E(mainnet address)
    address private BDT_PRICE_ORACLE; // address for BDT/USD price oracle
    address private USDT_PRICE_ORACLE; // address for USDT/USD price oracle

    IERC20Upgradeable private _usdt;
    IERC20Upgradeable private _bdt;
    uint256 private _slippageRate; // intial is 0.05%
    uint256 private _lockingPeriod;
    bool private _primaryLiquidity;

    /* Public Functions */
    /**
     * @notice this function is for initializing the contract
     * @dev set the token name, symbol and initial supply
     */
    function initialize(
        address usdt_,
        address bdt_,
        address router_
    ) public initializer {
        Helpers._checkAddress(usdt_);
        Helpers._checkAddress(bdt_);
        Helpers._checkAddress(router_);

        __Ownership_init();
        __ReentrancyGuard_init();

        USDT = usdt_;
        BDT = bdt_;
        _usdt = IERC20Upgradeable(usdt_);
        _bdt = IERC20Upgradeable(bdt_);
        PANCAKESWAP_V2_ROUTER = router_;
        _slippageRate = 5;
        _primaryLiquidity = true;
    }

    /* External Functions */
    /**
     * @notice function for adding liquidity for the pair USDT/BDT
     * @dev balances of both the tokens are verified before the transfer
     * @param amount_ amount of each tokens
     * @param lockingPeriod_ LP locking time
     */
    function AddLiquidity(
        uint256 amount_,
        uint256 lockingPeriod_
    ) external onlyOwner nonReentrant {
        Helpers._checkAmount(amount_);

        // check balance of both tokens
        if (_usdt.balanceOf(owner()) < amount_) {
            revert Errors.NotEnoughUSDTTokenForLiquidity();
        }

        if (_bdt.balanceOf(owner()) < amount_) {
            revert Errors.NotEnoughBDTTokenForLiquidity();
        }

        // transfer both the tokens to this smart contract
        _usdt.safeTransferFrom(owner(), address(this), amount_);
        _bdt.safeTransferFrom(owner(), address(this), amount_);

        // set locking period
        if (lockingPeriod_ > 0) {
            _lockingPeriod = lockingPeriod_;
        }

        // add liquidity and lock LP tokens
        uint256 amountMinExp_ = _getSlippageRate(amount_);
        _addLiquidity(amount_, amountMinExp_);
    }

    /**
     * @notice function for updating the slippage rate
     * @param rate_ new slippage rate
     */
    function modifySlippageRate(uint256 rate_) external onlyOwner {
        // rate should be between 0 and 10000 (0-100%)
        if (rate_ == 0 || rate_ > 10000) {
            revert Errors.InvalidRate();
        }

        // update slippage rate
        _slippageRate = rate_;
        emit Events.SlippageRateModified(rate_);
    }

    /**
     * @notice function for checking the balance of LP token for the pair USDT/BDT
     * @dev function is from PancakeRouter02
     * @param account address of which balance has to be computed
     */
    function getLPBalance(
        address account
    ) external view returns (uint256 balance) {
        address LP = IPancakeFactory(
            IPancakeRouter02(PANCAKESWAP_V2_ROUTER).factory()
        ).getPair(USDT, BDT);

        balance = IERC20Upgradeable(LP).balanceOf(account);
    }

    /**
     * @notice function for returing the slippage rate
     * @return slippageRate_ slippage rate
     */
    function getSlippageRate() external view returns (uint256) {
        return _slippageRate;
    }

    /* Private Helper Functions */
    /**
     * @notice function for adding liquidity to the Pancake swap for the pair USDT/BDT
     * @dev both tokens are from the smart contract. No need to transfer from external sender
     * @param amount_ amount of tokens to be added as lliquidity
     * @param amountMin_ min amount of tokens expected
     */
    function _addLiquidity(
        uint256 amount_,
        uint256 amountMin_
    ) private returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        Helpers._checkAmount(amountMin_);

        // give approval to the router for adding liquidity
        _approveUSDT(amount_);

        // check exist allowance dbfi
        _approveBDT(amount_);

        // add liquidity
        (amountA, amountB, liquidity) = IPancakeRouter02(PANCAKESWAP_V2_ROUTER)
            .addLiquidity(
                USDT,
                BDT,
                amount_,
                amount_,
                amountMin_,
                amountMin_,
                address(this),
                block.timestamp
            );

        emit Events.AddedLiquidity(amountA, amountB, liquidity);
    }

    /**
     * @notice function for approving USDT tokens to the router
     * @dev this will check the allowance given to the router
     * if the allowance exist, it will increase allowance by deudcting the
     * existing amount. Otherwise will give approval for the required amount
     */
    function _approveUSDT(uint256 amount_) private {
        uint256 allowance = _usdt.allowance(
            address(this),
            PANCAKESWAP_V2_ROUTER
        );

        // allow pancake swap router to spend the USDT
        if (allowance > 0) {
            _usdt.safeIncreaseAllowance(
                PANCAKESWAP_V2_ROUTER,
                amount_ - allowance
            );
        } else {
            _usdt.safeApprove(PANCAKESWAP_V2_ROUTER, amount_);
        }
    }

    /**
     * @notice function for approving BDT tokens to the router
     * @dev this will check the allowance given to the router
     * if the allowance exist, it will increase allowance by deducting the
     * existing amount. Otherwise will give approval for the required amount
     */
    function _approveBDT(uint256 amount_) private {
        uint256 allowance = _bdt.allowance(
            address(this),
            PANCAKESWAP_V2_ROUTER
        );

        // allow pancake swap router to spend the BDT
        if (allowance > 0) {
            _bdt.safeIncreaseAllowance(
                PANCAKESWAP_V2_ROUTER,
                amount_ - allowance
            );
        } else {
            _bdt.safeApprove(PANCAKESWAP_V2_ROUTER, amount_);
        }
    }

    /**
     * @notice function for computing the slippage rate
     * @param amount_ amount on which slippage has to be calculated
     * @return slippageAmount slippage amount which has to be deducted from expected amountOut
     */
    function _getSlippageRate(uint256 amount_) private view returns (uint256) {
        return (amount_ * _slippageRate) / 10000;
    }
}
