// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @author Digital Trust CSP
 * @notice Contract for managing liquidity for the pair USDT/BDT in pancake swap
 * @dev first time liquidity is added as per the price range of 1USDT/1BDT
 * @dev remaining liquidity is added by fetching the current price from chainlink oracle
 * @dev USDT address in BNB testnet 0x5bDD51572354BB72470Ff98f6428B12EEf3DC26f
 * @dev Router 0xD99D1c33F9fC3444f8101754aBC46c52416550D1 (testnet);
 * @dev Router 0x10ED43C718714eb63d5aA57B78B54704E256024E (mainnet)
 * @dev USDT/USD oracle 0xEca2605f0BCF2BA5966372C99837b1F182d3D620 (testnet)
 * @dev USDT/USD oracle 0xB97Ad0E74fa7d920791E90258A6E2085088b4320 (mainnet)
 * @dev intial slippage rate is 0.5%
 */

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../helpers/OwnershipUpgradeable.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter01.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/AggregatorV3Interface.sol";

contract BlueDiamondLiquidity is
    ReentrancyGuardUpgradeable,
    OwnershipUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* State Varialbes */
    address private USDT;
    address private BDT;
    address private PANCAKESWAP_V2_ROUTER;
    address private BDT_PRICE_ORACLE;
    address private USDT_PRICE_ORACLE;

    uint256 private _slippageRate;
    uint256 private _lockingPeriod;

    /* Public Functions */
    /**
     * @notice this function is for initializing the contract
     * @dev set the token addresses, router and oracles
     */
    function initialize(
        address usdt_,
        address bdt_,
        address router_,
        address usdtOracle_
    ) public initializer {
        Helpers._checkAddress(usdt_);
        Helpers._checkAddress(bdt_);
        Helpers._checkAddress(router_);
        Helpers._checkAddress(usdtOracle_);

        __Ownership_init();
        __ReentrancyGuard_init();

        USDT = usdt_;
        BDT = bdt_;
        PANCAKESWAP_V2_ROUTER = router_;
        USDT_PRICE_ORACLE = usdtOracle_;
        _slippageRate = 50;
    }

    /**
     * @notice function for checking the balance of LP token for the pair USDT/BDT
     * @dev function is from PancakeRouter02
     * @param account address of which balance has to be computed
     */
    function getLPBalance(
        address account
    ) public view returns (uint256 balance) {
        address LP_ = _getLPAddress();

        balance = IERC20Upgradeable(LP_).balanceOf(account);
    }

    /* External Functions */
    /**
     * @notice function for adding liquidity for the pair USDT/BDT
     * @dev balances of both the tokens are verified before the transfer
     * @dev current price for both the tokens will be fetched from the oracle if not primary liquidity
     * @param amountA_ amount of USDT token
     * @param lockingPeriod_ LP locking time in seconds
     * @param primaryLiquidity_ true if primary liquidity; false otherwise
     */
    function AddLiquidity(
        uint256 amountA_,
        uint256 lockingPeriod_,
        bool primaryLiquidity_
    ) external onlyOwner nonReentrant {
        Helpers._checkAmount(amountA_);

        IERC20Upgradeable _usdt = IERC20Upgradeable(USDT);
        IERC20Upgradeable _bdt = IERC20Upgradeable(BDT);

        // check balance of both tokens
        if (_usdt.balanceOf(owner()) < amountA_) {
            revert Errors.NotEnoughUSDTTokenForLiquidity();
        }

        // check if primary liquidity
        uint256 amountB_;

        if (primaryLiquidity_) {
            amountB_ = amountA_;
        } else {
            amountB_ = _getAmountBDT(amountA_);
            Helpers._checkAmount(amountB_);
        }

        // check BDT token balance
        if (_bdt.balanceOf(owner()) < amountB_) {
            revert Errors.NotEnoughBDTTokenForLiquidity();
        }

        // set locking period
        if (lockingPeriod_ > 0) {
            _lockingPeriod = block.timestamp + lockingPeriod_;
        }

        // transfer both the tokens to this smart contract
        _usdt.safeTransferFrom(owner(), address(this), amountA_);
        _bdt.safeTransferFrom(owner(), address(this), amountB_);

        uint256 amountAMin_ = amountA_ - _getSlippageRate(amountA_);
        uint256 amountBMin_ = amountB_ - _getSlippageRate(amountB_);

        Helpers._checkAmount(amountAMin_);
        Helpers._checkAmount(amountBMin_);

        // give approval to the router for adding liquidity
        _approveUSDT(_usdt, amountA_);
        _approveBDT(_bdt, amountB_);

        // add liquidity
        (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        ) = IPancakeRouter02(PANCAKESWAP_V2_ROUTER).addLiquidity(
                USDT,
                BDT,
                amountA_,
                amountB_,
                amountAMin_,
                amountBMin_,
                address(this),
                block.timestamp
            );

        emit Events.AddedLiquidity(amountA, amountB, liquidity);
    }

    /**
     * @notice function for removing liquidity
     * @param lpAmount_ amount of LP tokens that needs to be removed
     * @param account_ account to which the tokens has to be transferred
     * @dev need to find the amountAMin, amountBMin to avoid sandwich attack
     */
    function removeLiquidity(
        uint256 lpAmount_,
        address account_
    ) external onlyOwner nonReentrant {
        Helpers._checkAmount(lpAmount_);
        Helpers._checkAddress(account_);

        // check for LP balance
        uint256 lpBalance_ = getLPBalance(address(this));
        if (lpAmount_ > lpBalance_) {
            revert Errors.NotEnoughLPTokensToRemoveLiquidity();
        }

        // check for locking period
        if (_lockingPeriod > block.timestamp) {
            revert Errors.LockingPeriodNotOver();
        }

        // find minimum tokens to be received
        (uint256 amountAMin, uint256 amountBMin) = _getMinimumAmounts(
            lpAmount_
        );

        // remove liquidity
        (uint256 amountA, uint256 amountB) = IPancakeRouter02(
            PANCAKESWAP_V2_ROUTER
        ).removeLiquidity(
                USDT,
                BDT,
                lpAmount_,
                amountAMin - _getSlippageRate(amountAMin),
                amountBMin - _getSlippageRate(amountBMin),
                account_,
                block.timestamp
            );

        emit Events.RemovedLiquidity(amountA, amountB);
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
     * @notice function for updating the price oracle addresses
     * @param USDTOracle_ new USDT oracle address
     * @param BDTOracle_ new BDT oracle address
     */
    function modifyOracleAddresses(
        address USDTOracle_,
        address BDTOracle_
    ) external onlyOwner {
        Helpers._checkAddress(USDTOracle_);
        Helpers._checkAddress(BDTOracle_);

        USDT_PRICE_ORACLE = USDTOracle_;
        BDT_PRICE_ORACLE = BDTOracle_;
        emit Events.PriceOraclesModified(USDTOracle_, BDTOracle_);
    }

    /**
     * @notice function for updating the token addresses
     * @param USDT_ new USDT address
     * @param BDT_ new BDT address
     */
    function modifyTokenAddresses(
        address USDT_,
        address BDT_
    ) external onlyOwner {
        Helpers._checkAddress(USDT_);
        Helpers._checkAddress(BDT_);

        USDT = USDT_;
        BDT = BDT_;
        emit Events.TokenAddressesModified(USDT_, BDT_);
    }

    /**
     * @notice function for modifying router address
     * @param router_ pancake router address
     */
    function modifyRouterAddress(address router_) external onlyOwner {
        Helpers._checkAddress(router_);

        emit Events.RouterAddressModified(router_);
        PANCAKESWAP_V2_ROUTER = router_;
    }

    /**
     * @notice function for returing the slippage rate
     * @return slippageRate_ slippage rate
     */
    function slippageRate() external view returns (uint256) {
        return _slippageRate;
    }

    /**
     * @notice function for returing the oracle addresses
     */
    function oracleAddresses() external view returns (address, address) {
        return (USDT_PRICE_ORACLE, BDT_PRICE_ORACLE);
    }

    /**
     * @notice function for returing the token addresses
     */
    function tokenAddresses() external view returns (address, address) {
        return (USDT, BDT);
    }

    /**
     * @notice function for returing the pancake router address
     */
    function routerAddress() external view returns (address) {
        return (PANCAKESWAP_V2_ROUTER);
    }

    /**
     * @notice function for returing the locking period
     */
    function lockingPeriod() external view returns (uint256) {
        return _lockingPeriod;
    }

    /* Private Helper Functions */
    /**
     * @notice function for finding the minimum amount of tokens (USDT/BDT)
     * to be received upon removing liquidity
     * @param lpAmount_ amount of LP tokens to be removed
     */
    function _getMinimumAmounts(
        uint256 lpAmount_
    ) private returns (uint256, uint256) {
        address lpAddress_ = _getLPAddress();
        IERC20Upgradeable lp_ = IERC20Upgradeable(lpAddress_);
        uint256 totalSupply_ = lp_.totalSupply();

        uint256 amountAMin = (lpAmount_ *
            IERC20Upgradeable(USDT).balanceOf(lpAddress_)) / totalSupply_;
        uint256 amontBMin = (lpAmount_ *
            IERC20Upgradeable(BDT).balanceOf(lpAddress_)) / totalSupply_;

        _approveLP(lp_, lpAmount_);

        return (amountAMin, amontBMin);
    }

    /**
     * @notice function for retrieving the LP token address for the pair USDT/BDT
     * @return lpAddress_ LP address from the factory contract
     */
    function _getLPAddress() private view returns (address) {
        return
            IPancakeFactory(IPancakeRouter02(PANCAKESWAP_V2_ROUTER).factory())
                .getPair(USDT, BDT);
    }

    /**
     * @notice function for approving USDT tokens to the router
     * @dev this will check the allowance given to the router
     * if the allowance exist, it will increase allowance by deudcting the
     * existing amount. Otherwise will give approval for the required amount
     */
    function _approveUSDT(IERC20Upgradeable usdt_, uint256 amount_) private {
        uint256 allowance = usdt_.allowance(
            address(this),
            PANCAKESWAP_V2_ROUTER
        );

        // allow pancake swap router to spend the USDT
        if (allowance > 0) {
            usdt_.safeIncreaseAllowance(
                PANCAKESWAP_V2_ROUTER,
                amount_ - allowance
            );
        } else {
            usdt_.safeApprove(PANCAKESWAP_V2_ROUTER, amount_);
        }
    }

    /**
     * @notice function for approving LP tokens to the router
     * @dev this will check the allowance given to the router
     * if the allowance exist, it will increase allowance by deudcting the
     * existing amount. Otherwise will give approval for the required amount
     * @param lp_ LP token instance
     * @param lpAmount_ LP token amount
     */
    function _approveLP(IERC20Upgradeable lp_, uint256 lpAmount_) private {
        uint256 allowance = lp_.allowance(address(this), PANCAKESWAP_V2_ROUTER);

        // allow pancake swap router to spend the USDT
        if (allowance > 0) {
            lp_.safeIncreaseAllowance(
                PANCAKESWAP_V2_ROUTER,
                lpAmount_ - allowance
            );
        } else {
            lp_.safeApprove(PANCAKESWAP_V2_ROUTER, lpAmount_);
        }
    }

    /**
     * @notice function for approving BDT tokens to the router
     * @dev this will check the allowance given to the router
     * if the allowance exist, it will increase allowance by deducting the
     * existing amount. Otherwise will give approval for the required amount
     */
    function _approveBDT(IERC20Upgradeable bdt_, uint256 amount_) private {
        uint256 allowance = bdt_.allowance(
            address(this),
            PANCAKESWAP_V2_ROUTER
        );

        // allow pancake swap router to spend the BDT
        if (allowance > 0) {
            bdt_.safeIncreaseAllowance(
                PANCAKESWAP_V2_ROUTER,
                amount_ - allowance
            );
        } else {
            bdt_.safeApprove(PANCAKESWAP_V2_ROUTER, amount_);
        }
    }

    /**
     * @notice function for fetching the data from the oracles and find the amount of BDT tokens
     * @dev USDT/USD and BDT/USD price oracles are used
     * @param amountUSDT_ amount of USDT
     * @return amountBDT_ amount of BDT
     */
    function _getAmountBDT(
        uint256 amountUSDT_
    ) private view returns (uint256 amountBDT_) {
        Helpers._checkAddress(BDT_PRICE_ORACLE);

        // get price of BDT and USDT
        int256 usdtPrice_ = _getLatestPrice(USDT_PRICE_ORACLE);
        int256 bdtPrice_ = _getLatestPrice(BDT_PRICE_ORACLE);
        uint8 usdtDecimals_ = _getDecimals(USDT_PRICE_ORACLE);
        uint8 bdtDecimals_ = _getDecimals(BDT_PRICE_ORACLE);

        // if the price is zero or negative abort the txn
        if (usdtPrice_ <= 0 || bdtPrice_ <= 0) {
            revert Errors.InvalidPrice();
        }

        // check decimals
        if (usdtDecimals_ == 0 || bdtDecimals_ == 0) {
            revert Errors.ZeroDecimals();
        }

        // amount of BDT tokens for liquidity
        return
            (uint256(usdtPrice_) * amountUSDT_ * bdtDecimals_) /
            (uint256(bdtPrice_) * usdtDecimals_);
    }

    /**
     * @notice function for fetching the latest price for the token
     * @param priceFeed_ pricefeed address;
     * @return price price of the token in usd
     */
    function _getLatestPrice(address priceFeed_) private view returns (int256) {
        (, int256 price, , , ) = AggregatorV3Interface(priceFeed_)
            .latestRoundData();

        return price;
    }

    /**
     * @notice function for fetching the decimals places used in the pricefeed
     * @param priceFeed_ pricefeed address;
     * @return decimals decimals used in the pricefeed contract
     */
    function _getDecimals(address priceFeed_) private view returns (uint8) {
        return AggregatorV3Interface(priceFeed_).decimals();
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
