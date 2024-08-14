//SPDX-License-Identifier:MIT

pragma solidity ^0.8.26;

contract KillerDSCEngine {

    function depositCollateralAndMintKiller(address tokenCollateralAdd, uint256 collateralAmount, uint256 killerToMint) public {}

    function depositCollateral(address tokenCollateralAdd, uint256 collateralAmount) public {}

    function mintKiller(uint256 killerToMint) public {}
    
    function redeemCollateralAndBurnKiller(address tokenCollateralAdd, uint256 collateralAmount, uint256 killerToBurn) public {}

    function redeemCollateral(address tokenCollateralAdd, uint256 collateralAmount) public {}

    function BurnKiller(uint256 killerToBurn) public {}
}