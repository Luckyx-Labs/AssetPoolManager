// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Settlement} from "../src/Settlement.sol";

/**
 * @title DeploySettlement
 * @notice Deployment script for the Settlement contract
 * @dev Usage:
 *      Environment variables:
 *      - SETTLEMENT_ADMIN_ADDRESS: Admin address for executing batch settlements (EOA recommended)
 *      - DEPLOYER_PRIVATE_KEY: Private key of the deployer account
 * 
 *      Architecture:
 *      - Multi-sig wallet: Controls the AssetPool, transfers funds to Settlement contract
 *      - Settlement Admin (EOA): Executes batch payouts from Settlement contract to users
 */
contract DeploySettlement is Script {
    function run() external {
        // Load environment variables
        address settlementAdmin = vm.envAddress("SETTLEMENT_ADMIN_ADDRESS");
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console.log("Deploying Settlement contract...");
        console.log("Settlement Admin:", settlementAdmin);

        vm.startBroadcast(deployerPk);

        // Deploy Settlement contract (non-upgradeable, direct deployment)
        Settlement settlement = new Settlement(settlementAdmin);

        console.log("----------------------------------------");
        console.log("Settlement deployed at:", address(settlement));
        console.log("Settlement Admin:", settlementAdmin);
        console.log("----------------------------------------");

        vm.stopBroadcast();
    }
}
