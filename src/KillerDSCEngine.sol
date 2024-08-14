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
    error KillerDSCEngine__InvalidUSER();
    error KillerDSCEngine__TransferedFailed();

    /////////////////////////////
    ////    State Variables  ////
    /////////////////////////////

    KillerCoin private immutable i_killer;
    mapping(address tokenAdd => address pricefeedAdd) private s_ValidCollateralTokens;
    mapping(address user => uint256 amount) private s_killerMinted;
    mapping(address user => mapping(address tokenAdd => uint256 amount)) private s_depositedCollateral;

    /////////////////////////////
    ////     Events          ////
    /////////////////////////////

    event CollateralDeposited(address indexed user, address indexed tokenCollateralAdd, uint256 amount);
    event KillerCoinMinted(address indexed user, uint256 amount);
    event CollateralRedeemed(address indexed user, address indexed tokenCollateralAdd, uint256 amount);
    event KillerCoinBurned(address indexed user, uint256 amount);

    /////////////////////////////
    ////  Modifiers          ////
    /////////////////////////////

    modifier ValidCollateral(address tokenAdd) {
        if (s_ValidCollateralTokens[tokenAdd] == address(0)) {
            revert KillerDSCEngine__TokenNotAllowedAsColletaral(tokenAdd);
        }
        _;
    }

    modifier ValidAmount(uint256 amount) {
        if (amount == 0) {
            revert KillerDSCEngine__InvalidAmount();
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
        }

        i_killer = new KillerCoin();
    }

    function depositCollateralAndMintKiller(address tokenCollateralAdd, uint256 collateralAmount, uint256 killerToMint)
        public
    {
        depositCollateral(tokenCollateralAdd, collateralAmount);
        mintKiller(killerToMint);
    }

    function depositCollateral(address tokenCollateralAdd, uint256 collateralAmount) public {
        if (msg.sender == address(0)) {
            revert KillerDSCEngine__InvalidUSER();
        }
        _depositCollateral(msg.sender, tokenCollateralAdd, collateralAmount);
    }

    function mintKiller(uint256 killerToMint) public ValidAmount(killerToMint) {
        if (msg.sender == address(0)) {
            revert KillerDSCEngine__InvalidUSER();
        }
        _mintKiller(msg.sender, killerToMint);
    }

    function redeemCollateralAndBurnKiller(address tokenCollateralAdd, uint256 collateralAmount, uint256 killerToBurn)
        public
    {}

    function redeemCollateral(address tokenCollateralAdd, uint256 collateralAmount) public {
        if (msg.sender == address(0)) {
            revert KillerDSCEngine__InvalidUSER();
        }
        _redeemCollateral(msg.sender, tokenCollateralAdd, collateralAmount);
    }

    function burnKiller(uint256 killerToBurn) public {
        if (msg.sender == address(0)) {
            revert KillerDSCEngine__InvalidUSER();
        }
        _burnKiller(msg.sender, killerToBurn);
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

    function _redeemCollateral(address _from, address _tokenCollateral, uint256 _amount)
        internal
        ValidCollateral(_tokenCollateral)
        ValidAmount(_amount)
    {
        s_depositedCollateral[_from][_tokenCollateral] -= _amount;
        _revertIfHealthFactorIsBroken(_from);
        emit CollateralRedeemed(_from, _tokenCollateral, _amount);

        bool success = IERC20(_tokenCollateral).transfer(_from, _amount);
        if (!success) {
            revert KillerDSCEngine__TransferedFailed();
        }
    }

    function _burnKiller(address _from, uint256 _amount) internal ValidAmount(_amount) {
        s_killerMinted[_from] -= _amount;
        emit KillerCoinBurned(_from, _amount);

        bool success = i_killer.transferFrom(_from, address(this), _amount);
        if (!success) {
            revert KillerDSCEngine__TransferedFailed();
        }
        i_killer.burn(_amount);
    }

    function _revertIfHealthFactorIsBroken(address _to) internal {}
}
