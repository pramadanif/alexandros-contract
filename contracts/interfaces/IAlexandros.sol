// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAlexandros
 * @notice Interface definitions for the Alexandros Protocol
 * @dev Defines the core data structures and events for the "Programmable Lock" layer.
 */
interface IAlexandros {
    
    // ==========================================
    // Data Structures
    // ==========================================

    enum AgentStatus {
        ACTIVE,
        UPDATED,
        BANNED
    }

    struct Agent {
        uint256 id;
        bytes32 codeHash;       // Hash of the agent's off-chain code/logic
        AgentStatus status;     // Lifecycle status
        bytes32 metadataHash;   // IPFS hash of agent metadata
        uint256 lastUpdated;    // Timestamp of last status change
        address owner;          // Address authorized to update this agent
    }

    struct Permission {
        address grantee;        // The Agent (Manager) address
        address target;         // Target Contract (e.g., Uniswap Router)
        bytes4 selector;        // Function Selector (e.g., swapExactTokensForTokens)
        address asset;          // Token address (or address(0) for ETH)
        uint256 maxAmount;      // Spending cap
        uint256 expiresAt;      // Expiration timestamp
        bytes32 sessionKeyHash; // Hash of the ephemeral session key
        bool isRevoked;         // Explicit revocation flag
    }

    // ==========================================
    // Events (Critical for Envio)
    // ==========================================

    event PermissionGranted(
        bytes32 indexed permissionId,
        address indexed user,
        address indexed agent,
        address target,
        uint256 expiresAt
    );

    event PermissionRevoked(
        bytes32 indexed permissionId,
        address indexed user,
        string reason
    );

    event PermissionExpired(
        bytes32 indexed permissionId,
        address indexed user
    );

    event ExecutionAuthorized(
        bytes32 indexed permissionId,
        address indexed agent,
        address target,
        bytes4 selector,
        uint256 value
    );

    event AgentVerified(
        uint256 indexed agentId,
        bytes32 codeHash
    );

    event AgentBanned(
        uint256 indexed agentId,
        string reason
    );

    // ==========================================
    // Core Functions
    // ==========================================

    /**
     * @notice Validates if a specific execution is allowed by a permission.
     * @dev Must revert if any condition fails.
     * @param permissionId The unique identifier of the permission.
     * @param caller The address attempting the execution (usually the Agent).
     * @param target The contract being called.
     * @param value The ETH value being sent.
     * @param data The calldata of the execution.
     */
    function validatePermission(
        bytes32 permissionId,
        address caller,
        address target,
        uint256 value,
        bytes calldata data
    ) external view;
}
