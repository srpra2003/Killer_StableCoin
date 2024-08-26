// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier:MIT

pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KillerCoin} from "./KillerCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title KillerEngine
 * @author Sohamkumar Prajapati ---- smrp1720@gmail.com
 * @notice This is the Handling Engine for the Stablecoin Named Killer which is
 *         pegged to 1USD, algorihmically stable and WETH and WBTC are the two collateral
 *         token type which is accepted as collataral
 */
contract KillerDSCEngine {
    /////////////////////////////
    ////    State Variables  ////
    /////////////////////////////

    error KillerDSCEngine__TokensArrayLengthAndPricefeedsArrayLengthUnEqual();
    error KillerDSCEngine__TokenNotAllowedAsColletaral(address tokenAdd);
    error KillerDSCEngine__InvalidAmount();
    error KillerDSCEngine__InvalidAddress();
    error KillerDSCEngine__TransferedFailed();
    error KillerDSCEngine__HealthFactorIsBroken();
    error KillerDSCEngine__UserISNotUnderCollaterlized(address user);
    error KillerDSCEngine__LiquidationFailed();

    /////////////////////////////
    ////    State Variables  ////
    /////////////////////////////

    KillerCoin private immutable i_killer;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 80;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant IDEAL_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;
    mapping(address tokenAdd => address pricefeedAdd) private s_ValidCollateralTokens;
    mapping(address user => uint256 amount) private s_killerMinted;
    mapping(address user => mapping(address tokenAdd => uint256 amount)) private s_depositedCollateral;
    address[] private s_tokenAdds;

    /////////////////////////////
    ////     Events          ////
    /////////////////////////////

    event CollateralDeposited(address indexed user, address indexed tokenCollateralAdd, uint256 amount);
    event KillerCoinMinted(address indexed user, uint256 amount);
    event CollateralRedeemed(address indexed user, address indexed tokenCollateralAdd, uint256 amount);
    event KillerCoinBurned(address indexed user, address indexed onBehalfOf, uint256 amount);

    /////////////////////////////
    ////  Modifiers          ////
    /////////////////////////////

    modifier ValidCollateral(address _tokenAdd) {
        if (s_ValidCollateralTokens[_tokenAdd] == address(0)) {
            revert KillerDSCEngine__TokenNotAllowedAsColletaral(_tokenAdd);
        }
        _;
    }

    modifier ValidAmount(uint256 amount) {
        if (amount == 0) {
            revert KillerDSCEngine__InvalidAmount();
        }
        _;
    }

    modifier ValidAddress(address adds) {
        if (adds == address(0)) {
            revert KillerDSCEngine__InvalidAddress();
        }
        _;
    }

    /////////////////////////////
    ////    Functions        ////
    /////////////////////////////

    constructor(address[] memory validTokenAdd, address[] memory pricefeedAddes) {
        if (validTokenAdd.length != pricefeedAddes.length) {
            revert KillerDSCEngine__TokensArrayLengthAndPricefeedsArrayLengthUnEqual();
        }
        for (uint256 i = 0; i < validTokenAdd.length; i++) {
            s_ValidCollateralTokens[validTokenAdd[i]] = pricefeedAddes[i];
            s_tokenAdds.push(validTokenAdd[i]);
        }
        i_killer = new KillerCoin();
    }

    function depositCollateralAndMintKiller(address tokenCollateralAdd, uint256 collateralAmount, uint256 killerToMint)
        public
    {
        depositCollateral(tokenCollateralAdd, collateralAmount);
        mintKiller(killerToMint);
    }

    function depositCollateral(address tokenCollateralAdd, uint256 collateralAmount) public ValidAddress(msg.sender) {
        _depositCollateral(msg.sender, tokenCollateralAdd, collateralAmount);
    }

    function mintKiller(uint256 killerToMint) public ValidAmount(killerToMint) ValidAddress(msg.sender) {
        _mintKiller(msg.sender, killerToMint);
    }

    function redeemCollateralAndBurnKiller(address tokenCollateralAdd, uint256 collateralAmount, uint256 killerToBurn)
        public
    {
        burnKiller(killerToBurn);
        redeemCollateral(tokenCollateralAdd, collateralAmount);
    }

    function redeemCollateral(address tokenCollateralAdd, uint256 collateralAmount) public ValidAddress(msg.sender) {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAdd, collateralAmount);
    }

    function burnKiller(uint256 killerToBurn) public ValidAddress(msg.sender) {
        _burnKiller(msg.sender, msg.sender, killerToBurn);
    }

    //when person1 goes undercollaterlized then anyone let suppose personx will
    // liquidate person1 's position personx will call liquidate function where
    // killer coin will be deducted from his account the amount will be specified by him
    // in return personx will be given the collateral of person1 personx have to specify which
    // token he wants in return among available in system at that time
    /**
     *
     * @param tokenCollateralAdd tokenCollateral which will be incentivized
     *  to the user who is liquidating the undercollateralized users's position
     * @param underCollateralizedUser user who is undercollaterilized
     * @param debtToCover the amount of debt to cover in "usd" --> make sure debtToCover is
     *                                                                   in the precision of 1e18
     */
    function liquidate(address tokenCollateralAdd, address underCollateralizedUser, uint256 debtToCover)
        public
        ValidCollateral(tokenCollateralAdd)
        ValidAddress(underCollateralizedUser)
        ValidAmount(debtToCover)
    {
        uint256 startingUserHealthFactor = calculateHealthFactor(underCollateralizedUser);
        if (startingUserHealthFactor >= IDEAL_HEALTH_FACTOR) {
            revert KillerDSCEngine__UserISNotUnderCollaterlized(underCollateralizedUser);
        }

        uint256 tokenValue = calculateValueInTokensFromUSD(tokenCollateralAdd, debtToCover);
        uint256 additionalIncentive = (tokenValue * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        _redeemCollateral(underCollateralizedUser, msg.sender, tokenCollateralAdd, tokenValue + additionalIncentive);
        _burnKiller(underCollateralizedUser, msg.sender, debtToCover);

        uint256 endingUserHealthFactor = calculateHealthFactor(underCollateralizedUser);

        if (endingUserHealthFactor < startingUserHealthFactor) {
            revert KillerDSCEngine__LiquidationFailed();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _depositCollateral(address _to, address _tokenCollateral, uint256 _amount)
        internal
        ValidCollateral(_tokenCollateral)
        ValidAmount(_amount)
    {
        s_depositedCollateral[_to][_tokenCollateral] += _amount;
        emit CollateralDeposited(_to, _tokenCollateral, _amount);

        bool success = IERC20(_tokenCollateral).transferFrom(_to, address(this), _amount);

        if (!success) {
            revert KillerDSCEngine__TransferedFailed();
        }
    }

    function _mintKiller(address _to, uint256 _amount) internal ValidAmount(_amount) {
        s_killerMinted[_to] += _amount;
        _revertIfHealthFactorIsBroken(_to);
        emit KillerCoinMinted(_to, _amount);

        bool isMinted = i_killer.mint(_to, _amount);
        if (!isMinted) {
            revert KillerDSCEngine__TransferedFailed();
        }
    }

    function _redeemCollateral(address _from, address _to, address _tokenCollateral, uint256 _amount)
        internal
        ValidCollateral(_tokenCollateral)
        ValidAmount(_amount)
    {
        s_depositedCollateral[_from][_tokenCollateral] -= _amount;
        _revertIfHealthFactorIsBroken(_from);
        emit CollateralRedeemed(_from, _tokenCollateral, _amount);

        bool success = IERC20(_tokenCollateral).transferFrom(address(this), _to, _amount);
        if (!success) {
            revert KillerDSCEngine__TransferedFailed();
        }
    }

    function _burnKiller(address _onBehalfOf, address _from, uint256 _amount) internal ValidAmount(_amount) {
        s_killerMinted[_onBehalfOf] -= _amount;
        emit KillerCoinBurned(_onBehalfOf, _from, _amount);

        bool success = i_killer.transferFrom(_from, address(this), _amount);
        if (!success) {
            revert KillerDSCEngine__TransferedFailed();
        }
        i_killer.burn(_amount);
    }

    function _revertIfHealthFactorIsBroken(address _to) internal view {
        uint256 userHealthFactor = calculateHealthFactor(_to);
        if (userHealthFactor < IDEAL_HEALTH_FACTOR) {
            revert KillerDSCEngine__HealthFactorIsBroken();
        }
    }

    function getUserInformation(address user)
        public
        view
        ValidAddress(user)
        returns (uint256 collateralValueInUSD, uint256 killerMinted)
    {
        collateralValueInUSD = 0;
        for (uint256 i = 0; i < s_tokenAdds.length; i++) {
            collateralValueInUSD += getUSDValue(s_tokenAdds[i], s_depositedCollateral[user][s_tokenAdds[i]]);
        }
        killerMinted = s_killerMinted[user];
    }

    function getUSDValue(address tokenAddress, uint256 amount)
        public
        view
        ValidCollateral(tokenAddress)
        returns (uint256)
    {
        AggregatorV3Interface datafeed = AggregatorV3Interface(s_ValidCollateralTokens[tokenAddress]);
        (
            /* uint80 roundID */
            ,
            int256 answer,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = datafeed.latestRoundData();

        uint8 decimals = datafeed.decimals();
        uint256 decimalReversePrecision = 10 ** (18 - decimals);

        return ((uint256(answer) * decimalReversePrecision) * amount) / PRECISION;
    }

    function calculateValueInTokensFromUSD(address tokenCollateralAdd, uint256 usdAmount)
        public
        view
        returns (uint256)
    {
        uint256 usdPerToken = getUSDValue(tokenCollateralAdd, 1);

        return (usdAmount * PRECISION) / usdPerToken;
    }

    function calculateHealthFactor(address user) public view ValidAddress(user) returns (uint256) {
        (uint256 collateralValueInUSD, uint256 killerMinted) = getUserInformation(user);
        if (killerMinted == 0) {
            return type(uint256).max;
        }

        uint256 collateralThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 healthFactor = (collateralThreshold) / killerMinted;
        return healthFactor;
    }
}
