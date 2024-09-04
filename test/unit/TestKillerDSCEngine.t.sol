//SPDX-Licene-Identifier: MIT

pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {KillerDSCEngine} from "../../src/KillerDSCEngine.sol";
import {KillerCoin} from "../../src/KillerCoin.sol";
import {DeployKillerEngine} from "../../script/DeployKillerEngine.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {FailingtransferFromERC20Mock} from "../mocks/FailingtransferFromERC20Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract TestKillerDSCEngine is Test {
    error Low_Level_Call_Failed();

    KillerDSCEngine private killerEngine;
    KillerCoin private killerCoin;
    DeployKillerEngine private deployKillerEngine;
    HelperConfig private helperConfig;

    address private wethTokenAddress;
    address private wbtcTokenAddress;
    address private wethToUSDPricefeedAddress;
    address private wbtcToUSDPricefeedAddress;

    address[] private tokenAdds;
    address[] private priceFeddAdds;

    address private USER = makeAddr("user");
    uint256 private INITIAL_BALANCE = 100 ether;
    uint256 private COLLATERAL_TO_DEPOSIT = 1 wei;

    event CollateralDeposited(address indexed user, address indexed tokenCollateralAdd, uint256 amount);
    event CollateralRedeemed(address indexed user, address indexed tokenCollateralAdd, uint256 amount);

    function setUp() public {
        deployKillerEngine = new DeployKillerEngine();
        (killerEngine, helperConfig) = deployKillerEngine.run();
        killerCoin = KillerCoin(killerEngine.getKillerTokenAddress());

        (wethTokenAddress, wbtcTokenAddress, wethToUSDPricefeedAddress, wbtcToUSDPricefeedAddress,) =
            helperConfig.activeNetconfig();

        vm.startPrank(USER);
        vm.deal(USER, 10 * INITIAL_BALANCE);

        if (block.chainid == 31337) {
            ERC20Mock(wethTokenAddress).mint(USER, INITIAL_BALANCE);
            ERC20Mock(wbtcTokenAddress).mint(USER, INITIAL_BALANCE);
        } else if (block.chainid == 11155111) {
            (bool success,) = payable(wethTokenAddress).call{value: INITIAL_BALANCE}(abi.encodeWithSignature("deposit"));
            (bool callSuccess,) =
                payable(wbtcTokenAddress).call{value: INITIAL_BALANCE}(abi.encodeWithSignature("deposit"));

            if (!success || !callSuccess) {
                revert Low_Level_Call_Failed();
            }
        }
    }

    function testEngineInitializationfailsOnInvalidArgumentPassedInConstructor() public {
        address fakeWethAdd = makeAddr("FakeWethAddress");
        address fakeWbtcAdd = makeAddr("FAkeWbtcAddress");
        tokenAdds.push(fakeWethAdd);
        tokenAdds.push(fakeWbtcAdd);

        address fakeWethtoUSDPriceFeed = address(new MockV3Aggregator(8, 2000));
        priceFeddAdds.push(fakeWethtoUSDPriceFeed);

        vm.startPrank(USER);
        vm.expectRevert(KillerDSCEngine.KillerDSCEngine__TokensArrayLengthAndPricefeedsArrayLengthUnEqual.selector);
        new KillerDSCEngine(tokenAdds, priceFeddAdds);
        vm.stopPrank();
    }

    function testKillerEngineIntiateTheERC20KillerCoinCorrectlyAndOwnerIsSet() public view {
        address killerCoinContractOwner = killerCoin.owner();
        assertEq(killerCoinContractOwner, address(killerEngine));
    }

    function testUserCanOnlyDepositCollateralWhichISAllowedAndValidAmount() public {
        ERC20Mock invalidToken = new ERC20Mock();
        uint256 amountToDeposit = 5 ether;
        uint256 zeroAmount = 0 ether;

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                KillerDSCEngine.KillerDSCEngine__TokenNotAllowedAsColletaral.selector, address(invalidToken)
            )
        );
        killerEngine.depositCollateral(address(invalidToken), amountToDeposit);

        vm.expectRevert(KillerDSCEngine.KillerDSCEngine__InvalidAmount.selector);
        killerEngine.depositCollateral(address(wethTokenAddress), zeroAmount);
        vm.stopPrank();
    }

    function testDepositCollateralDepositTheAmountToEngineAddressAndCutsTheAmountFromUser() public {
        uint256 initialUserWethBalance = ERC20Mock(wethTokenAddress).balanceOf(USER);
        uint256 amountToTransfer = 5 ether;
        uint256 initialEngineWethTokenBalance = ERC20Mock(wethTokenAddress).balanceOf(address(killerEngine));

        vm.startPrank(USER);
        ERC20Mock(wethTokenAddress).approve(address(killerEngine), amountToTransfer);
        killerEngine.depositCollateral(wethTokenAddress, amountToTransfer);
        vm.stopPrank();

        uint256 finalUserWethBalance = ERC20Mock(wethTokenAddress).balanceOf(USER);
        uint256 finalEngineWethBalance = ERC20Mock(wethTokenAddress).balanceOf(address(killerEngine));

        assertEq(initialUserWethBalance, finalUserWethBalance + amountToTransfer);
        assertEq(initialEngineWethTokenBalance + amountToTransfer, finalEngineWethBalance);
    }

    function testDepositCollateralRevertsOnTokenTransferingFailedFromUserToEngine() public {
        FailingtransferFromERC20Mock testToken = new FailingtransferFromERC20Mock();
        MockV3Aggregator testTokenPriceFeed = new MockV3Aggregator(8, 2000);
        tokenAdds.push(address(testToken));
        priceFeddAdds.push(address(testTokenPriceFeed));

        KillerDSCEngine testKillerEngine = new KillerDSCEngine(tokenAdds, priceFeddAdds);

        uint256 amountToDeposit = 5 ether;

        vm.startPrank(USER);
        testToken.approve(address(testKillerEngine), amountToDeposit);
        vm.expectRevert(KillerDSCEngine.KillerDSCEngine__TransferedFailed.selector);
        testKillerEngine.depositCollateral(address(testToken), amountToDeposit);
        vm.stopPrank();
    }

    function testUserCanNotMintKillerCoinThanHeCanAccordingToSystem() public collateralDeposited {
        (uint256 collateralDepositedInUSD, uint256 killerMinted) = killerEngine.getUserInformation(USER);
        uint256 LiquidationThreshold = killerEngine.getLiquidationThreshold();
        uint256 LIquidationPrecision = killerEngine.getLiquidationPrecision();
        uint256 maxKillerCoinUSERCanMint = ((collateralDepositedInUSD * LiquidationThreshold) / (LIquidationPrecision)) - killerMinted;

        vm.startPrank(USER);
        vm.expectRevert(KillerDSCEngine.KillerDSCEngine__HealthFactorIsBroken.selector);
        killerEngine.mintKiller(maxKillerCoinUSERCanMint + 1);
    }

    function testUserCanRedeemCollateral() public collateralDeposited {
        vm.startPrank(USER);
        vm.expectEmit(true,true,false,true,address(killerEngine));
        emit CollateralRedeemed(USER, wethTokenAddress, COLLATERAL_TO_DEPOSIT);
        killerEngine.redeemCollateral(wethTokenAddress, COLLATERAL_TO_DEPOSIT);
        vm.stopPrank();
    }

    function testUserCanNotRedeemCollateralThanHehaveDeposited() public collateralDeposited {
        vm.startPrank(USER);
        vm.expectRevert();
        killerEngine.redeemCollateral(wethTokenAddress,COLLATERAL_TO_DEPOSIT + 10 ether);
        vm.stopPrank();
    }

    function testUserCanRedeemCollateralAfterBurningTheKillerCoin() public collateralDeposited {
        
        (uint256 collateralDepositedInUSD, uint256 killerMinted) = killerEngine.getUserInformation(USER);
        uint256 LiquidationThreshold = killerEngine.getLiquidationThreshold();
        uint256 LIquidationPrecision = killerEngine.getLiquidationPrecision();
        uint256 maxKillerCoinUSERCanMint = ((collateralDepositedInUSD * LiquidationThreshold) / (LIquidationPrecision)) - killerMinted;
        
        console.log(collateralDepositedInUSD);
        console.log(killerMinted);
        console.log(maxKillerCoinUSERCanMint);     

        vm.startBroadcast(USER);
        killerEngine.mintKiller(maxKillerCoinUSERCanMint/2);
        vm.stopBroadcast();

        (collateralDepositedInUSD, killerMinted) = killerEngine.getUserInformation(USER);
        console.log(collateralDepositedInUSD);
        console.log(killerMinted);
        maxKillerCoinUSERCanMint = ((collateralDepositedInUSD * LiquidationThreshold) / (LIquidationPrecision)) - killerMinted;
        console.log(maxKillerCoinUSERCanMint);  

        uint256 killerToBurn = killerMinted;    // wants to burn all the killer
        uint256 collateralToRedeem  = COLLATERAL_TO_DEPOSIT; // wants to reddem all the collateral which was deposited as the collateral of weth token     
        
        vm.startPrank(USER);
        killerCoin.approve(address(killerEngine),killerToBurn);    // USER must approve the killer Engine inorder to burn that amount of token in behalf of him 
        killerEngine.redeemCollateralAndBurnKiller(wethTokenAddress,collateralToRedeem,killerToBurn);
        vm.stopPrank();
        
    }

    function testZeroAddressCannotDepositAndRedeemCollateralAndCannotMintOrBurnKillerCoin() public {

        address zeroAddress = address(0);
        vm.deal(zeroAddress,INITIAL_BALANCE);

        vm.startPrank(zeroAddress);
        // vm.expectRevert();
        // ERC20Mock(wethTokenAddress).approve(address(killerEngine),COLLATERAL_TO_DEPOSIT);
        vm.expectRevert();
        killerEngine.depositCollateral(wethTokenAddress, COLLATERAL_TO_DEPOSIT);
        
        vm.expectRevert();
        killerEngine.mintKiller(5000);

        vm.expectRevert();
        killerEngine.redeemCollateral(wethTokenAddress,10 ether);

        vm.expectRevert();
        killerEngine.burnKiller(100);
        
    }

    modifier collateralDeposited() {
        vm.startPrank(USER);
        ERC20Mock(wethTokenAddress).approve(address(killerEngine), COLLATERAL_TO_DEPOSIT);
        killerEngine.depositCollateral(wethTokenAddress, COLLATERAL_TO_DEPOSIT);
        vm.stopPrank();
        _;
    }
}
