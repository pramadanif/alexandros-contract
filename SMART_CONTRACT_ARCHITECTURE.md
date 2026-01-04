# ALEXANDROS Smart Contract Architecture

## 1. Architecture Diagram

```mermaid
graph TD
    User[User Smart Account] -->|Delegates via EIP-7702| PA[PermissionAuthority]
    Manager[Manager Agent] -->|Calls| PA
    PA -->|Checks Status| AR[AgentRegistry]
    PA -->|Verifies Scope| PL[Permission Logic]
    PL -->|Allowed| Target[Target Contract (DeFi)]
    PL -->|Denied| Revert[Revert Transaction]

    subgraph "On-Chain Trust Substrate"
        AR
        PA
    end

    subgraph "Off-Chain Intelligence"
        Backend[Policy Engine]
        Envio[Indexer]
    end

    Backend -->|Updates| AR
    PA -.->|Emits Events| Envio
```

## 2. State Variable Definitions

### A. Agent Registry (`AgentRegistry.sol`)
This contract serves as the whitelist for valid agents.

```solidity
// ERC-8004 Compatible Storage
mapping(uint256 => Agent) public agents;
mapping(address => uint256) public agentIds; // address -> ID lookup

struct Agent {
    uint256 id;
    bytes32 codeHash;       // Hash of the agent's off-chain code/logic
    AgentStatus status;     // ACTIVE, UPDATED, BANNED
    bytes32 metadataHash;   // IPFS hash of agent metadata
    uint256 lastUpdated;    // Timestamp
    address owner;          // Who can update this agent
}

enum AgentStatus {
    ACTIVE,
    UPDATED,
    BANNED
}
```

### B. Permission Authority (`PermissionAuthority.sol`)
This contract enforces the "programmable lock".

```solidity
// Permission Storage
// mapping(permissionHash => Permission)
mapping(bytes32 => Permission) public permissions;

// mapping(userAddress => mapping(agentId => permissionHash))
mapping(address => mapping(uint256 => bytes32)) public activePermissions;

// Nonces to prevent replay of signatures
mapping(address => uint256) public nonces;

struct Permission {
    address grantee;        // The Agent (Manager) address
    address target;         // Target Contract (e.g., Uniswap Router)
    bytes4 selector;        // Function Selector (e.g., swapExactTokensForTokens)
    address asset;          // Token address (or address(0) for ETH)
    uint256 maxAmount;      // Spending cap
    uint256 expiresAt;      // Timestamp
    bytes32 sessionKeyHash; // Hash of the ephemeral session key
    bool isRevoked;         // Explicit revocation flag
}
```

## 3. Permission Lifecycle State Machine

The permission lifecycle is strictly linear unless revoked.

1.  **CREATED**:
    *   User signs an EIP-712 typed data payload defining the `Permission`.
    *   Transaction submitted to `grantPermission()`.
    *   State: `permissions[hash]` is stored. `activePermissions[user][agent]` is set.
    *   *Event*: `PermissionGranted`

2.  **ACTIVE**:
    *   Current block timestamp < `expiresAt`.
    *   `isRevoked` is `false`.
    *   Agent is `ACTIVE` in `AgentRegistry`.
    *   Calls flow through `validatePermission()`.

3.  **EXPIRED**:
    *   Current block timestamp >= `expiresAt`.
    *   Calls revert.
    *   *Event*: `PermissionExpired` (emitted upon failed attempt or cleanup).

4.  **REVOKED**:
    *   User calls `revokePermission()`.
    *   `isRevoked` set to `true`.
    *   Calls revert immediately.
    *   *Event*: `PermissionRevoked`

## 4. Security Assumptions

1.  **Registry Integrity**: We assume the `AgentRegistry` owner (DAO or Admin) properly vets agents before setting them to `ACTIVE`. The contract does not verify code logic, only identity.
2.  **Hash Collision Resistance**: We assume `keccak256` collisions are impossible for permission IDs.
3.  **Clock Synchronization**: We rely on `block.timestamp` for expiration. Miners can manipulate this slightly, but not enough to impact macro-level permissions (hours/days).
4.  **Fail-Closed**: If the Registry is paused or an Agent is banned, all active permissions for that agent effectively cease to function immediately.
5.  **EIP-7702 Atomicity**: We assume the Smart Account implementation correctly calls `PermissionAuthority` before executing any delegated action.

## 5. EIP-7702 Enforcement on-chain

EIP-7702 allows an EOA to temporarily "set code" to become a Smart Account during a transaction. Alexandros leverages this to inject the **Permission Authority** logic.

**Mechanism:**

1.  **Delegation**: The user signs an EIP-7702 authorization that sets their account code to a **Smart Account Implementation** (e.g., a minimal proxy).
2.  **Validation Hook**: This Smart Account Implementation is hardcoded to call `PermissionAuthority.validatePermission()` in its `execute` or `validateUserOp` function.
3.  **Execution Flow**:
    *   **Input**: `(target, value, data, permissionId, signature)`
    *   **Check 1**: Is `msg.sender` (the Agent) the `grantee` in `permissions[permissionId]`?
    *   **Check 2**: Is `permissions[permissionId]` valid (not expired, not revoked)?
    *   **Check 3**: Does `data` match `selector`?
    *   **Check 4**: Does `value` or parsed amount match `maxAmount`?
    *   **Check 5**: Is the Agent `ACTIVE` in `AgentRegistry`?
    *   **Result**: If all pass, the Smart Account executes the call. If any fail, it reverts.

This ensures that **no action** can be taken by the Manager Agent unless it strictly adheres to the on-chain permission policy.

## 6. Events (Envio Indexing)

```solidity
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
```
