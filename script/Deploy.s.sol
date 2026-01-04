// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/AgentRegistry.sol";
import "../contracts/PermissionAuthority.sol";

/**
 * @title DeployAlexandros
 * @notice Deployment script for Alexandros Protocol on Arbitrum Sepolia
 * 
 * Usage:
 *   # With private key from env
 *   forge script script/Deploy.s.sol:DeployAlexandros --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 *   
 *   # With hardware wallet (ledger)
 *   forge script script/Deploy.s.sol:DeployAlexandros --rpc-url $RPC_URL --broadcast --ledger
 */
contract DeployAlexandros is Script {
    function run() external {
        // Try to get private key from env, fallback to msg.sender for simulation
        uint256 deployerPrivateKey;
        address deployer;
        
        try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
            deployerPrivateKey = pk;
            deployer = vm.addr(pk);
        } catch {
            // For simulation without PRIVATE_KEY, use a default address
            deployer = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // Foundry default
            console.log("No PRIVATE_KEY found, using simulation mode");
        }
        
        console.log("Deploying Alexandros Protocol...");
        console.log("Deployer:", deployer);
        
        vm.startBroadcast();
        
        // Deploy Agent Registry first
        AgentRegistry agentRegistry = new AgentRegistry();
        console.log("AgentRegistry deployed at:", address(agentRegistry));
        
        // Deploy Permission Authority with registry reference
        PermissionAuthority permissionAuthority = new PermissionAuthority(address(agentRegistry));
        console.log("PermissionAuthority deployed at:", address(permissionAuthority));
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("");
        console.log("===========================================");
        console.log("  ALEXANDROS PROTOCOL DEPLOYED");
        console.log("===========================================");
        console.log("Network: Arbitrum Sepolia (421614)");
        console.log("AgentRegistry:", address(agentRegistry));
        console.log("PermissionAuthority:", address(permissionAuthority));
        console.log("Owner:", deployer);
        console.log("===========================================");
        console.log("");
        console.log("Next steps:");
        console.log("1. Update alexandros-indexer/.env with contract addresses");
        console.log("2. Update alexandros-be/.env with contract addresses");
        console.log("3. Update alexandros-fe/.env.local with contract addresses");
        console.log("4. Run: cd alexandros-indexer && pnpm run dev");
    }
}
