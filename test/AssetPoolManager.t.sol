// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AssetPoolManager} from "../src/AssetPoolManagerMultiSig.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AssetPoolManagerETHTest is Test {
    AssetPoolManager public assetPoolManager;
    address public admin = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    
    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant FEE_RATE = 10; // 0.1%
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    function setUp() public {
        // Deploy implementation contract
        AssetPoolManager implementation = new AssetPoolManager();
        
        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(
            AssetPoolManager.initialize.selector,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        assetPoolManager = AssetPoolManager(payable(address(proxy)));
        
        // transfer ETH to admin
        vm.deal(admin, 100 ether);
        
        // transfer ETH to user1 and user2
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
    }

    function testAdminHash() public view {
        console.logBytes32(ADMIN_ROLE);
    }
    
    function testETHDeposit() public {
        uint256 depositAmount = 1 ether;
        
        // check before deposit - should be 0 for a new pool
        assertEq(assetPoolManager.poolBalance(assetPoolManager.ETH_ADDRESS()), 0);
        
        // deposit ETH
        vm.prank(user1);
        assetPoolManager.depositETH{value: depositAmount}();
        
        // check after deposit - no fee charged on deposit
        assertEq(assetPoolManager.poolBalance(assetPoolManager.ETH_ADDRESS()), depositAmount);
    }
    
    function testETHWithdraw() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;
        uint256 fee = (withdrawAmount * FEE_RATE) / 10000;
        uint256 netAmount = withdrawAmount - fee;
        
        // deposit ETH first
        vm.prank(user1);
        assetPoolManager.depositETH{value: depositAmount}();
        
        // check before withdraw
        assertEq(assetPoolManager.poolBalance(assetPoolManager.ETH_ADDRESS()), depositAmount);
        
        uint256 userBalanceBefore = user1.balance;
        uint256 adminBalanceBefore = admin.balance;
        
        // withdraw ETH
        vm.prank(user1);
        assetPoolManager.withdrawETH(withdrawAmount, user2);
        
        // check after withdraw
        // Contract deducts full withdrawAmount from user balance and pool balance
        // Transfers netAmount to user and fee to admin
        assertEq(user1.balance, userBalanceBefore + netAmount); // user receives net amount after fee
        assertEq(admin.balance, adminBalanceBefore + fee); // admin receives fee directly
    }
    
    function test_RevertWhen_ETHDepositBelowMinimum() public {
        uint256 depositAmount = 0.001 ether; // below minimum deposit
        
        vm.prank(user1);
        vm.expectRevert(bytes("AssetPoolManager: below minimum deposit"));
        assetPoolManager.depositETH{value: depositAmount}();
    }
    
    function test_RevertWhen_ETHWithdrawInsufficientBalance() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether; //  more than what is available
        
        vm.prank(user1);
        assetPoolManager.depositETH{value: depositAmount}();
        
        // try to withdraw more than the balance
        vm.prank(user1);
        vm.expectRevert(bytes("AssetPoolManager: insufficient ETH balance"));
        assetPoolManager.withdrawETH(withdrawAmount,user2);
    }
    
    
    
    function test_RevertWhen_DirectETHTransfer() public {
        // sending ETH directly to the contract should fail
        vm.expectRevert(bytes("AssetPoolManager: use depositETH function"));
        (bool success, ) = address(assetPoolManager).call{value: 1 ether}("");
        success; // avoid unused variable warnings
    }
    
    function testAdminRole() public view {
        // verify admin has ADMIN_ROLE
        assertTrue(assetPoolManager.hasRole(assetPoolManager.ADMIN_ROLE(), admin));
        assertTrue(assetPoolManager.hasRole(assetPoolManager.DEFAULT_ADMIN_ROLE(), admin));
    }

    // test get pool all balances
    function testGetPoolAllBalances() public {
        vm.startPrank(admin);
        (address[] memory tokens, uint256[] memory balances) = assetPoolManager.getPoolAllBalances();
        vm.stopPrank();
        assertEq(tokens.length, balances.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(assetPoolManager.poolBalance(tokens[i]), balances[i]);
        }
    }

  
}