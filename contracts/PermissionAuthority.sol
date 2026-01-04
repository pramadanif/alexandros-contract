// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IAlexandros.sol";
import "./AgentRegistry.sol";

/**
 * @title PermissionAuthority
 * @notice Core permission management for Alexandros Protocol
 * @dev Handles permission granting, revocation, and validation
 */
contract PermissionAuthority is IAlexandros {
    // ===========================================
    // State Variables
    // ===========================================
    
    /// @notice Agent Registry reference
    AgentRegistry public immutable agentRegistry;
    
    /// @notice Permission storage by ID
    mapping(bytes32 => Permission) public permissions;
    
    /// @notice Active permissions per user per agent
    mapping(address => mapping(address => bytes32)) public activePermissions;
    
    /// @notice User nonces for signature replay protection
    mapping(address => uint256) public nonces;
    
    /// @notice Contract owner
    address public owner;
    
    /// @notice Paused state
    bool public paused;
    
    // ===========================================
    // Constants
    // ===========================================
    
    bytes32 public constant PERMISSION_TYPEHASH = keccak256(
        "Permission(address grantee,address target,bytes4 selector,address asset,uint256 maxAmount,uint256 expiresAt,bytes32 sessionKeyHash,uint256 nonce)"
    );
    
    bytes32 public immutable DOMAIN_SEPARATOR;
    
    // ===========================================
    // Modifiers
    // ===========================================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "PermissionAuthority: not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "PermissionAuthority: paused");
        _;
    }
    
    // ===========================================
    // Constructor
    // ===========================================
    
    constructor(address _agentRegistry) {
        require(_agentRegistry != address(0), "PermissionAuthority: zero registry");
        
        agentRegistry = AgentRegistry(_agentRegistry);
        owner = msg.sender;
        
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Alexandros"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }
    
    // ===========================================
    // Permission Granting
    // ===========================================
    
    /**
     * @notice Grant permission to an agent
     * @param grantee Agent address receiving permission
     * @param target Target contract address
     * @param selector Function selector allowed
     * @param asset Token address (address(0) for ETH)
     * @param maxAmount Maximum spending amount
     * @param expiresAt Expiration timestamp
     * @param sessionKeyHash Hash of session key
     */
    function grantPermission(
        address grantee,
        address target,
        bytes4 selector,
        address asset,
        uint256 maxAmount,
        uint256 expiresAt,
        bytes32 sessionKeyHash
    ) external whenNotPaused returns (bytes32) {
        require(grantee != address(0), "PermissionAuthority: zero grantee");
        require(target != address(0), "PermissionAuthority: zero target");
        require(expiresAt > block.timestamp, "PermissionAuthority: already expired");
        
        // Verify agent is registered and active
        require(
            agentRegistry.isAgentActiveByAddress(grantee),
            "PermissionAuthority: agent not active"
        );
        
        // Generate permission ID
        bytes32 permissionId = _generatePermissionId(
            msg.sender,
            grantee,
            target,
            selector,
            asset,
            maxAmount,
            expiresAt,
            sessionKeyHash,
            nonces[msg.sender]++
        );
        
        // Store permission
        permissions[permissionId] = Permission({
            grantee: grantee,
            target: target,
            selector: selector,
            asset: asset,
            maxAmount: maxAmount,
            expiresAt: expiresAt,
            sessionKeyHash: sessionKeyHash,
            isRevoked: false
        });
        
        // Track active permission
        activePermissions[msg.sender][grantee] = permissionId;
        
        emit PermissionGranted(permissionId, msg.sender, grantee, target, expiresAt);
        
        return permissionId;
    }
    
    /**
     * @notice Grant permission with signature (meta-transaction)
     */
    function grantPermissionWithSignature(
        address grantor,
        address grantee,
        address target,
        bytes4 selector,
        address asset,
        uint256 maxAmount,
        uint256 expiresAt,
        bytes32 sessionKeyHash,
        bytes calldata signature
    ) external whenNotPaused returns (bytes32) {
        require(grantee != address(0), "PermissionAuthority: zero grantee");
        require(target != address(0), "PermissionAuthority: zero target");
        require(expiresAt > block.timestamp, "PermissionAuthority: already expired");
        
        // Verify agent is active
        require(
            agentRegistry.isAgentActiveByAddress(grantee),
            "PermissionAuthority: agent not active"
        );
        
        uint256 nonce = nonces[grantor]++;
        
        // Verify signature
        bytes32 structHash = keccak256(
            abi.encode(
                PERMISSION_TYPEHASH,
                grantee,
                target,
                selector,
                asset,
                maxAmount,
                expiresAt,
                sessionKeyHash,
                nonce
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        
        address signer = _recoverSigner(digest, signature);
        require(signer == grantor, "PermissionAuthority: invalid signature");
        
        // Generate permission ID
        bytes32 permissionId = _generatePermissionId(
            grantor,
            grantee,
            target,
            selector,
            asset,
            maxAmount,
            expiresAt,
            sessionKeyHash,
            nonce
        );
        
        // Store permission
        permissions[permissionId] = Permission({
            grantee: grantee,
            target: target,
            selector: selector,
            asset: asset,
            maxAmount: maxAmount,
            expiresAt: expiresAt,
            sessionKeyHash: sessionKeyHash,
            isRevoked: false
        });
        
        activePermissions[grantor][grantee] = permissionId;
        
        emit PermissionGranted(permissionId, grantor, grantee, target, expiresAt);
        
        return permissionId;
    }
    
    // ===========================================
    // Permission Revocation
    // ===========================================
    
    /**
     * @notice Revoke a permission
     * @param permissionId The permission to revoke
     * @param reason Reason for revocation
     */
    function revokePermission(
        bytes32 permissionId,
        string calldata reason
    ) external whenNotPaused {
        Permission storage perm = permissions[permissionId];
        require(perm.grantee != address(0), "PermissionAuthority: not found");
        require(!perm.isRevoked, "PermissionAuthority: already revoked");
        
        // Only grantor or owner can revoke
        bytes32 activePermId = activePermissions[msg.sender][perm.grantee];
        require(
            activePermId == permissionId || msg.sender == owner,
            "PermissionAuthority: not authorized"
        );
        
        perm.isRevoked = true;
        
        // Clear active permission if grantor
        if (activePermId == permissionId) {
            delete activePermissions[msg.sender][perm.grantee];
        }
        
        emit PermissionRevoked(permissionId, msg.sender, reason);
    }
    
    /**
     * @notice Batch revoke permissions for an agent
     */
    function revokeAllForAgent(
        address agent,
        string calldata reason
    ) external whenNotPaused {
        bytes32 permissionId = activePermissions[msg.sender][agent];
        require(permissionId != bytes32(0), "PermissionAuthority: no permission");
        
        Permission storage perm = permissions[permissionId];
        perm.isRevoked = true;
        delete activePermissions[msg.sender][agent];
        
        emit PermissionRevoked(permissionId, msg.sender, reason);
    }
    
    // ===========================================
    // Permission Validation (IAlexandros)
    // ===========================================
    
    /**
     * @notice Validate if execution is allowed
     * @dev Called by Smart Account before executing delegated action
     */
    function validatePermission(
        bytes32 permissionId,
        address caller,
        address target,
        uint256 value,
        bytes calldata data
    ) external view override {
        Permission storage perm = permissions[permissionId];
        
        // Check 1: Permission exists
        require(perm.grantee != address(0), "PermissionAuthority: not found");
        
        // Check 2: Caller is the grantee
        require(perm.grantee == caller, "PermissionAuthority: not grantee");
        
        // Check 3: Not revoked
        require(!perm.isRevoked, "PermissionAuthority: revoked");
        
        // Check 4: Not expired
        require(block.timestamp < perm.expiresAt, "PermissionAuthority: expired");
        
        // Check 5: Target matches
        require(perm.target == target, "PermissionAuthority: wrong target");
        
        // Check 6: Selector matches (if specified)
        if (perm.selector != bytes4(0) && data.length >= 4) {
            bytes4 callSelector = bytes4(data[:4]);
            require(perm.selector == callSelector, "PermissionAuthority: wrong selector");
        }
        
        // Check 7: Value within limit (for ETH)
        if (perm.asset == address(0)) {
            require(value <= perm.maxAmount, "PermissionAuthority: exceeds limit");
        }
        
        // Check 8: Agent is still active in registry
        require(
            agentRegistry.isAgentActiveByAddress(caller),
            "PermissionAuthority: agent not active"
        );
    }
    
    /**
     * @notice Execute authorized action and emit event
     * @dev Called after validatePermission succeeds
     */
    function authorizeExecution(
        bytes32 permissionId,
        address target,
        uint256 value,
        bytes calldata data
    ) external whenNotPaused {
        // Validate first
        this.validatePermission(permissionId, msg.sender, target, value, data);
        
        Permission storage perm = permissions[permissionId];
        bytes4 selector = data.length >= 4 ? bytes4(data[:4]) : bytes4(0);
        
        emit ExecutionAuthorized(permissionId, msg.sender, target, selector, value);
    }
    
    // ===========================================
    // View Functions
    // ===========================================
    
    /**
     * @notice Get permission details
     */
    function getPermission(bytes32 permissionId) external view returns (Permission memory) {
        return permissions[permissionId];
    }
    
    /**
     * @notice Check if permission is valid
     */
    function isPermissionValid(bytes32 permissionId) external view returns (bool) {
        Permission storage perm = permissions[permissionId];
        
        if (perm.grantee == address(0)) return false;
        if (perm.isRevoked) return false;
        if (block.timestamp >= perm.expiresAt) return false;
        if (!agentRegistry.isAgentActiveByAddress(perm.grantee)) return false;
        
        return true;
    }
    
    /**
     * @notice Get active permission for user-agent pair
     */
    function getActivePermission(
        address user,
        address agent
    ) external view returns (bytes32) {
        return activePermissions[user][agent];
    }
    
    /**
     * @notice Check and emit expiration event
     */
    function checkExpiration(bytes32 permissionId, address user) external {
        Permission storage perm = permissions[permissionId];
        
        if (perm.grantee != address(0) && 
            !perm.isRevoked && 
            block.timestamp >= perm.expiresAt) {
            emit PermissionExpired(permissionId, user);
        }
    }
    
    // ===========================================
    // Admin Functions
    // ===========================================
    
    function pause() external onlyOwner {
        paused = true;
    }
    
    function unpause() external onlyOwner {
        paused = false;
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "PermissionAuthority: zero address");
        owner = newOwner;
    }
    
    // ===========================================
    // Internal Functions
    // ===========================================
    
    function _generatePermissionId(
        address grantor,
        address grantee,
        address target,
        bytes4 selector,
        address asset,
        uint256 maxAmount,
        uint256 expiresAt,
        bytes32 sessionKeyHash,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                grantor,
                grantee,
                target,
                selector,
                asset,
                maxAmount,
                expiresAt,
                sessionKeyHash,
                nonce
            )
        );
    }
    
    function _recoverSigner(
        bytes32 digest,
        bytes memory signature
    ) internal pure returns (address) {
        require(signature.length == 65, "PermissionAuthority: invalid sig length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        if (v < 27) {
            v += 27;
        }
        
        require(v == 27 || v == 28, "PermissionAuthority: invalid sig v");
        
        return ecrecover(digest, v, r, s);
    }
}
