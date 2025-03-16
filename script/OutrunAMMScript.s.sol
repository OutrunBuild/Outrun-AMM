// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./BaseScript.s.sol";
import {IOutrunDeployer} from "./IOutrunDeployer.sol";
import {OutrunAMMPair} from "../src/core/OutrunAMMPair.sol";
import {OutrunAMMERC20} from "../src/core/OutrunAMMERC20.sol";
import {OutrunAMMRouter} from "../src/router/OutrunAMMRouter.sol";
import {ReferralManager} from "../src/referral/ReferralManager.sol";
import {OutrunAMMFactory, IOutrunAMMFactory} from "../src/core/OutrunAMMFactory.sol";

contract OutrunAMMScript is BaseScript {
    address internal owner;
    address internal feeTo;
    address internal referralManager;
    address internal OUTRUN_DEPLOYER;
    address internal pairImplementation;

    mapping(uint256 chainId => address) public WETHs;

    function run() public broadcaster {
        owner = vm.envAddress("OWNER");
        feeTo = vm.envAddress("FEE_TO");
        OUTRUN_DEPLOYER = vm.envAddress("OUTRUN_DEPLOYER");
        pairImplementation = vm.envAddress("PAIR_IMPLEMENTATION");
        _chainsInit();
        // _deployPairImplementation(0);

        _deploy(0);
        
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
        WETHs[10143] = vm.envAddress("MONAD_TESTNET_WMOD");
        // WETHs[11155420] = vm.envAddress("OPTIMISTIC_SEPOLIA_WETH");
        // WETHs[300] = vm.envAddress("ZKSYNC_SEPOLIA_WETH");
        // WETHs[59141] = vm.envAddress("LINEA_SEPOLIA_WETH");
    }

    function _deploy(uint256 nonce) internal {

        // // 0.3% fee
        // address factory0 = _deployFactory(30, nonce);

        address factory0 = _deployFactory(30, nonce);

        // 1% fee
        address factory1 = _deployFactory(100, nonce);

        // OutrunAMMRouter
        _deployOutrunAMMRouter(factory0, factory1, nonce);
    }

    function _deployPairImplementation(uint256 nonce) internal returns (address implementation) {
        bytes32 salt = keccak256(abi.encodePacked("OutrunAMMPairImplementation", nonce));
        implementation = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, type(OutrunAMMPair).creationCode);

        console.log("OutrunAMMPairImplementation deployed on %s", implementation);
    }

    function _deployFactory(uint256 swapFeeRate, uint256 nonce) internal returns (address factoryAddr) {
        // Deploy OutrunAMMFactory By OutrunDeployer
        bytes32 salt = keccak256(abi.encodePacked("OutrunAMMFactory", swapFeeRate, nonce));
        bytes memory creationCode = abi.encodePacked(
            type(OutrunAMMFactory).creationCode,
            abi.encode(owner, pairImplementation, swapFeeRate)
        );
        factoryAddr = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, creationCode);
        IOutrunAMMFactory(factoryAddr).setFeeTo(feeTo);

        console.log("%d fee OutrunAMMFactory deployed on %s", swapFeeRate, factoryAddr);
    }

    function _deployOutrunAMMRouter(address factory0, address factory01, uint256 nonce) internal {
        // Deploy OutrunAMMFactory By OutrunDeployer
        bytes32 salt = keccak256(abi.encodePacked("OutrunAMMRouter", nonce));
        bytes memory creationCode = abi.encodePacked(
            type(OutrunAMMRouter).creationCode,
            abi.encode(factory0, factory01, WETHs[block.chainid])
        );
        address routerAddr = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, creationCode);

        console.log("OutrunAMMRouter deployed on %s", routerAddr);
    }
}
