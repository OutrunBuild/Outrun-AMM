// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./BaseScript.s.sol";
import {IOutrunDeployer} from "./IOutrunDeployer.sol";
import {OutrunAMMPair} from "../src/core/OutrunAMMPair.sol";
import {IMEVGuard, MEVGuard} from "../src/core/MEVGuard.sol";
import {OutrunAMMERC20} from "../src/core/OutrunAMMERC20.sol";
import {OutrunAMMRouter} from "../src/router/OutrunAMMRouter.sol";
import {ReferralManager} from "../src/referral/ReferralManager.sol";
import {MemeverseLiquidityRouter} from "../src/router/MemeverseLiquidityRouter.sol";
import {OutrunAMMFactory, IOutrunAMMFactory} from "../src/core/OutrunAMMFactory.sol";

contract OutrunAMMScript is BaseScript {
    address internal owner;
    address internal feeTo;
    address internal OUTRUN_DEPLOYER;
    address internal pairImplementation;
    address internal referralManager;

    address internal OUTRUN_AMM_FACTORY_30;
    address internal OUTRUN_AMM_FACTORY_100;

    mapping(uint256 chainId => address) public WETHs;
    mapping(uint256 chainId => uint256) public antiFrontDefendBlocks;

    function run() public broadcaster {
        owner = vm.envAddress("OWNER");
        feeTo = vm.envAddress("FEE_TO");
        OUTRUN_DEPLOYER = vm.envAddress("OUTRUN_DEPLOYER");
        pairImplementation = vm.envAddress("PAIR_IMPLEMENTATION");
        OUTRUN_AMM_FACTORY_30 = vm.envAddress("OUTRUN_AMM_FACTORY_30");
        OUTRUN_AMM_FACTORY_100 = vm.envAddress("OUTRUN_AMM_FACTORY_100");

        _chainsInit();

        // _deployPairImplementation(5);
        _deploy(6);
        
        // ReferralManager
        // referralManager = address(new ReferralManager(owner));
        // console.log("ReferralManager deployed on %s", referralManager);
    }

    function _chainsInit() internal {
        WETHs[97] = vm.envAddress("BSC_TESTNET_WBNB");
        WETHs[84532] = vm.envAddress("BASE_SEPOLIA_WETH");
        WETHs[421614] = vm.envAddress("ARBITRUM_SEPOLIA_WETH");
        WETHs[43113] = vm.envAddress("AVALANCHE_FUJI_WAVAX");
        WETHs[80002] = vm.envAddress("POLYGON_AMOY_WPOL");
        WETHs[57054] = vm.envAddress("SONIC_BLAZE_WS");
        WETHs[168587773] = vm.envAddress("BLAST_SEPOLIA_WETH");
        WETHs[534351] = vm.envAddress("SCROLL_SEPOLIA_WETH");
        // WETHs[10143] = vm.envAddress("MONAD_TESTNET_WMOD");
        // WETHs[11155420] = vm.envAddress("OPTIMISTIC_SEPOLIA_WETH");
        // WETHs[300] = vm.envAddress("ZKSYNC_SEPOLIA_WETH");
        // WETHs[59141] = vm.envAddress("LINEA_SEPOLIA_WETH");

        antiFrontDefendBlocks[97] = 400;        // 1.5s
        antiFrontDefendBlocks[84532] = 300;     // 2s
        antiFrontDefendBlocks[421614] = 2400;    // 0.25s
        antiFrontDefendBlocks[43113] = 400;     // 1.5s
        antiFrontDefendBlocks[80002] = 300;     // 2s
        antiFrontDefendBlocks[57054] = 1800;     // 0.33s
        antiFrontDefendBlocks[168587773] = 300; // 2s
        antiFrontDefendBlocks[534351] = 300;    // 3s
        // antiFrontDefendBlocks[10143] = 1200;     // 0.5s
        // antiFrontDefendBlocks[11155420] = 300;  // 2s
        // antiFrontDefendBlocks[300] = 600;       // 1s
        // antiFrontDefendBlocks[59141] = 300;     // 2s
    }

    function _deployPairImplementation(uint256 nonce) internal returns (address implementation) {
        bytes32 salt = keccak256(abi.encodePacked("OutrunAMMPairImplementation", nonce));
        implementation = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, type(OutrunAMMPair).creationCode);

        console.log("OutrunAMMPairImplementation deployed on %s", implementation);
    }

    function _deploy(uint256 nonce) internal {
        // MEVGuard
        address guard = _deployMEVGuard(nonce);

        // 0.3% fee
        address factory0 = _deployFactory(guard, 30, nonce);

        // 1% fee
        address factory1 = _deployFactory(guard, 100, nonce);

        IMEVGuard(guard).setFactoryStatus(factory0, true);
        IMEVGuard(guard).setFactoryStatus(factory1, true);

        // OutrunAMMRouter
        _deployOutrunAMMRouter(guard, factory0, factory1, nonce);

        // LiquidityRouter for POL minting
        _deployLiquidityRouter(factory0, factory1, nonce);
    }

    function _deployMEVGuard(uint256 nonce) internal returns (address guard) {
        bytes32 salt = keccak256(abi.encodePacked("OutrunMEVGuard", nonce));
        uint256 antiFrontDefendBlock = antiFrontDefendBlocks[block.chainid];
        uint256 antiMEVFeePercentage = 5000;      // 50%
        uint256 antiMEVAmountOutLimitRate = 50;   // 0.5%
        bytes memory creationCode = abi.encodePacked(
            type(MEVGuard).creationCode,
            abi.encode(owner, antiFrontDefendBlock, antiMEVFeePercentage, antiMEVAmountOutLimitRate)
        );
        guard = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, creationCode);

        console.log("OutrunMEVGuard deployed on %s", guard);
    }

    function _deployFactory(address guard, uint256 swapFeeRate, uint256 nonce) internal returns (address factoryAddr) {
        bytes32 salt = keccak256(abi.encodePacked("OutrunAMMFactory", swapFeeRate, nonce));
        bytes memory creationCode = abi.encodePacked(
            type(OutrunAMMFactory).creationCode,
            abi.encode(owner, pairImplementation, guard, swapFeeRate)
        );
        factoryAddr = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, creationCode);
        IOutrunAMMFactory(factoryAddr).setFeeTo(feeTo);

        console.log("%d fee OutrunAMMFactory deployed on %s", swapFeeRate, factoryAddr);
    }

    function _deployOutrunAMMRouter(address guard, address factory0, address factory01, uint256 nonce) internal {
        bytes32 salt = keccak256(abi.encodePacked("OutrunAMMRouter", nonce));
        bytes memory creationCode = abi.encodePacked(
            type(OutrunAMMRouter).creationCode,
            abi.encode(factory0, factory01, WETHs[block.chainid], guard)
        );
        address routerAddr = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, creationCode);

        console.log("OutrunAMMRouter deployed on %s", routerAddr);
    }

    function _deployLiquidityRouter(address factory0, address factory01, uint256 nonce) internal {
        bytes32 salt = keccak256(abi.encodePacked("MemeverseLiquidityRouter", nonce));
        bytes memory creationCode = abi.encodePacked(
            type(MemeverseLiquidityRouter).creationCode,
            abi.encode(factory0, factory01)
        );
        address routerAddr = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, creationCode);

        console.log("MemeverseLiquidityRouter deployed on %s", routerAddr);
    }
}
