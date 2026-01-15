// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";
import {AssetPoolManagerMultiSig} from "../src/AssetPoolManagerMultiSig.sol";

contract DeployAssetPoolManagerMultiSigProxy is Script {
    // Env vars:
    // - ADMIN_ADDRESS: initial admin address for the AssetPoolManager contract
    // - DEPLOYER_PRIVATE_KEY: deployer private key
    // - PROXY_ADMIN_OWNER(optional): ProxyAdmin owner, default is ADMIN_ADDRESS

    function run() external {
        address adminAddress = vm.envAddress("ADMIN_ADDRESS");
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address proxyAdminOwner = vm.envOr("PROXY_ADMIN_OWNER", adminAddress);

        vm.startBroadcast(deployerPk);

        // 1) deploy logic contract
        AssetPoolManagerMultiSig impl = new AssetPoolManagerMultiSig();

        // 2) prepare initialize data
        bytes memory initData = abi.encodeWithSelector(AssetPoolManagerMultiSig.initialize.selector, adminAddress);

        // 3) deploy TransparentUpgradeableProxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            proxyAdminOwner,
            initData
        );

        // 4) get the automatically created ProxyAdmin address
        address proxyAdmin = address(uint160(uint256(vm.load(address(proxy), bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)))));

        console.log("Implementation:", address(impl));
        console.log("Proxy:", address(proxy));
        console.log("ProxyAdmin:", proxyAdmin);
        console.log("Admin (contract role):", adminAddress);
        console.log("ProxyAdmin Owner:", proxyAdminOwner);

        vm.stopBroadcast();
    }
}


