// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AssetPoolManagerMultiSig} from "../src/AssetPoolManagerMultiSig.sol";
import {Settlement} from "../src/Settlement.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AssetPoolManagerTest is Test {
    AssetPoolManagerMultiSig public assetPoolManager;
    Settlement public settlement;
    
    address public admin = address(1);
    address public settlementAdmin = address(4);
    address public user1 = address(2);
    address public user2 = address(3);
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address public constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    
    function setUp() public {
        // Deploy AssetPoolManager with proxy
        AssetPoolManagerMultiSig implementation = new AssetPoolManagerMultiSig();
        
        bytes memory initData = abi.encodeWithSelector(
            AssetPoolManagerMultiSig.initialize.selector,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        assetPoolManager = AssetPoolManagerMultiSig(payable(address(proxy)));
        
        // Deploy Settlement contract (non-upgradeable)
        settlement = new Settlement(settlementAdmin);
        
        // Fund test accounts
        vm.deal(admin, 100 ether);
        vm.deal(settlementAdmin, 10 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    // ============ AssetPoolManager Tests ============

    function testAdminRole() public view {
        assertTrue(assetPoolManager.hasRole(ADMIN_ROLE, admin));
        assertTrue(assetPoolManager.hasRole(assetPoolManager.DEFAULT_ADMIN_ROLE(), admin));
    }

    function testETHDeposit() public {
        uint256 depositAmount = 1 ether;
        
        assertEq(assetPoolManager.poolBalance(ETH_ADDRESS), 0);
        
        vm.prank(user1);
        assetPoolManager.depositETH{value: depositAmount}();
        
        assertEq(assetPoolManager.poolBalance(ETH_ADDRESS), depositAmount);
    }
    
    function testETHWithdrawByAdmin() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;
        
        // Deposit first
        vm.prank(user1);
        assetPoolManager.depositETH{value: depositAmount}();
        
        uint256 user2BalanceBefore = user2.balance;
        
        // Admin withdraws to user2
        vm.prank(admin);
        assetPoolManager.withdrawETH(withdrawAmount, user2);
        
        assertEq(assetPoolManager.poolBalance(ETH_ADDRESS), depositAmount - withdrawAmount);
        assertEq(user2.balance, user2BalanceBefore + withdrawAmount);
    }
    
    function test_RevertWhen_NonAdminWithdraws() public {
        uint256 depositAmount = 1 ether;
        
        vm.prank(user1);
        assetPoolManager.depositETH{value: depositAmount}();
        
        // Non-admin tries to withdraw
        vm.prank(user1);
        vm.expectRevert("AssetPoolManager: must have admin role");
        assetPoolManager.withdrawETH(0.5 ether, user1);
    }
    
    function test_RevertWhen_DirectETHTransfer() public {
        vm.expectRevert("AssetPoolManager: use depositETH function");
        (bool success, ) = address(assetPoolManager).call{value: 1 ether}("");
        success; // silence warning
    }
    
    function testGetPoolAllBalances() public {
        vm.prank(user1);
        assetPoolManager.depositETH{value: 1 ether}();
        
        (address[] memory tokens, uint256[] memory balances) = assetPoolManager.getPoolAllBalances();
        
        assertEq(tokens.length, balances.length);
        assertEq(tokens[0], ETH_ADDRESS);
        assertEq(balances[0], 1 ether);
    }

    function testPauseUnpause() public {
        // Admin pauses
        vm.prank(admin);
        assetPoolManager.pause();
        
        // Deposit should fail when paused
        vm.prank(user1);
        vm.expectRevert();
        assetPoolManager.depositETH{value: 1 ether}();
        
        // Admin unpauses
        vm.prank(admin);
        assetPoolManager.unpause();
        
        // Deposit should work again
        vm.prank(user1);
        assetPoolManager.depositETH{value: 1 ether}();
        
        assertEq(assetPoolManager.poolBalance(ETH_ADDRESS), 1 ether);
    }

    // ============ Settlement Tests ============

    function testSettlementAdminRole() public view {
        assertTrue(settlement.hasRole(ADMIN_ROLE, settlementAdmin));
    }

    function testSettlementReceiveETH() public {
        // Admin transfers funds to settlement
        vm.prank(admin);
        (bool success, ) = address(settlement).call{value: 5 ether}("");
        assertTrue(success);
        
        assertEq(settlement.getETHBalance(), 5 ether);
    }

    function testBatchTransferPayout() public {
        // Fund settlement contract
        vm.deal(address(settlement), 10 ether);
        
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = address(5);
        
        address[] memory tokens = new address[](3);
        tokens[0] = ETH_ADDRESS;
        tokens[1] = ETH_ADDRESS;
        tokens[2] = ETH_ADDRESS;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 0.5 ether;
        
        uint256 user1BalanceBefore = user1.balance;
        uint256 user2BalanceBefore = user2.balance;
        
        vm.prank(settlementAdmin);
        settlement.batchTransferPayout(recipients, tokens, amounts);
        
        assertEq(user1.balance, user1BalanceBefore + 1 ether);
        assertEq(user2.balance, user2BalanceBefore + 2 ether);
        assertEq(address(5).balance, 0.5 ether);
    }

    function test_RevertWhen_NonAdminBatchPayout() public {
        vm.deal(address(settlement), 10 ether);
        
        address[] memory recipients = new address[](1);
        recipients[0] = user1;
        
        address[] memory tokens = new address[](1);
        tokens[0] = ETH_ADDRESS;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        
        vm.prank(user1);
        vm.expectRevert("Settlement: must have admin role");
        settlement.batchTransferPayout(recipients, tokens, amounts);
    }

    function test_RevertWhen_BatchSizeExceedsMax() public {
        vm.deal(address(settlement), 100 ether);
        
        // Create arrays with 26 items (exceeds MAX_BATCH_SIZE of 25)
        address[] memory recipients = new address[](26);
        address[] memory tokens = new address[](26);
        uint256[] memory amounts = new uint256[](26);
        
        for (uint256 i = 0; i < 26; i++) {
            recipients[i] = address(uint160(100 + i));
            tokens[i] = ETH_ADDRESS;
            amounts[i] = 0.1 ether;
        }
        
        vm.prank(settlementAdmin);
        vm.expectRevert("Settlement: invalid batch size");
        settlement.batchTransferPayout(recipients, tokens, amounts);
    }

    function testSettlementEmergencyWithdraw() public {
        vm.deal(address(settlement), 5 ether);
        
        uint256 adminBalanceBefore = settlementAdmin.balance;
        
        vm.prank(settlementAdmin);
        settlement.emergencyWithdrawETH(settlementAdmin, 3 ether);
        
        assertEq(settlement.getETHBalance(), 2 ether);
        assertEq(settlementAdmin.balance, adminBalanceBefore + 3 ether);
    }

    function testSettlementPauseUnpause() public {
        vm.deal(address(settlement), 10 ether);
        
        // Pause
        vm.prank(settlementAdmin);
        settlement.pause();
        
        // Batch payout should fail when paused
        address[] memory recipients = new address[](1);
        recipients[0] = user1;
        address[] memory tokens = new address[](1);
        tokens[0] = ETH_ADDRESS;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        
        vm.prank(settlementAdmin);
        vm.expectRevert();
        settlement.batchTransferPayout(recipients, tokens, amounts);
        
        // Unpause
        vm.prank(settlementAdmin);
        settlement.unpause();
        
        // Should work again
        vm.prank(settlementAdmin);
        settlement.batchTransferPayout(recipients, tokens, amounts);
        
        assertEq(user1.balance, 100 ether + 1 ether);
    }

    // ============ Integration Test ============

    function testFullFlow_DepositToPoolThenSettlement() public {
        // Step 1: Users deposit to AssetPoolManager
        vm.prank(user1);
        assetPoolManager.depositETH{value: 10 ether}();
        
        assertEq(assetPoolManager.poolBalance(ETH_ADDRESS), 10 ether);
        
        // Step 2: Admin withdraws from pool to Settlement contract
        vm.prank(admin);
        assetPoolManager.withdrawETH(5 ether, address(settlement));
        
        assertEq(assetPoolManager.poolBalance(ETH_ADDRESS), 5 ether);
        assertEq(settlement.getETHBalance(), 5 ether);
        
        // Step 3: Settlement admin executes batch payout
        address[] memory recipients = new address[](2);
        recipients[0] = address(10);
        recipients[1] = address(11);
        
        address[] memory tokens = new address[](2);
        tokens[0] = ETH_ADDRESS;
        tokens[1] = ETH_ADDRESS;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2 ether;
        amounts[1] = 3 ether;
        
        vm.prank(settlementAdmin);
        settlement.batchTransferPayout(recipients, tokens, amounts);
        
        assertEq(address(10).balance, 2 ether);
        assertEq(address(11).balance, 3 ether);
        assertEq(settlement.getETHBalance(), 0);
    }
}