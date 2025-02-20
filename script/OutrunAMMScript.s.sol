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

    address internal WETH;

    function run() public broadcaster {
        owner = vm.envAddress("OWNER");
        feeTo = vm.envAddress("FEE_TO");
        OUTRUN_DEPLOYER = vm.envAddress("OUTRUN_DEPLOYER");
        pairImplementation = vm.envAddress("PAIR_IMPLEMENTATION");

        // _deployPairImplementation(4);

        _deploy(13);
        
        // ReferralManager
        // referralManager = address(new ReferralManager(owner));
        // console.log("ReferralManager deployed on %s", referralManager);
    }

    function _deploy(uint256 nonce) internal {
        if (block.chainid == vm.envUint("BASE_SEPOLIA_CHAINID")) {
            WETH = vm.envAddress("BASE_SEPOLIA_WETH");
        } else if (block.chainid == vm.envUint("SCROLL_SEPOLIA_CHAINID")) {
            WETH = vm.envAddress("SCROLL_SEPOLIA_WETH");
        } else if (block.chainid == vm.envUint("BSC_TESTNET_CHAINID")) {
            WETH = vm.envAddress("BSC_TESTNET_WBNB");
        }

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
            abi.encode(factory0, factory01, WETH)
        );
        address routerAddr = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(salt, creationCode);

        console.log("OutrunAMMRouter deployed on %s", routerAddr);
    }
}
