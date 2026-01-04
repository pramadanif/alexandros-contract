// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IAlexandros.sol";

/**
 * @title AgentRegistry
 * @notice ERC-8004 compatible agent registry for Alexandros Protocol
 * @dev Manages agent lifecycle: registration, verification, updates, and banning
 */
contract AgentRegistry is IAlexandros {
    // ===========================================
    // State Variables
    // ===========================================
    
    /// @notice Counter for agent IDs
    uint256 private _nextAgentId;
    
    /// @notice Agent storage by ID
    mapping(uint256 => Agent) public agents;
    
    /// @notice Address to agent ID lookup
    mapping(address => uint256) public agentIds;
    
    /// @notice Registry owner/admin
    address public owner;
    
    /// @notice Paused state
    bool public paused;
    
    // ===========================================
    // Events
    // ===========================================
    
    event AgentRegistered(
        uint256 indexed agentId,
        address indexed agentAddress,
        bytes32 codeHash,
        address owner
    );
    
    event AgentUpdated(
        uint256 indexed agentId,
        bytes32 oldCodeHash,
        bytes32 newCodeHash
    );
    
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    
    event Paused(address account);
    event Unpaused(address account);
    
    // ===========================================
    // Modifiers
    // ===========================================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "AgentRegistry: caller is not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "AgentRegistry: paused");
        _;
    }
    
    modifier onlyAgentOwner(uint256 agentId) {
        require(agents[agentId].owner == msg.sender, "AgentRegistry: not agent owner");
        _;
    }
    
    // ===========================================
    // Constructor
    // ===========================================
    
    constructor() {
        owner = msg.sender;
        _nextAgentId = 1;
    }
    
    // ===========================================
    // Agent Registration
    // ===========================================
    
    /**
     * @notice Register a new agent
     * @param agentAddress The address of the agent
     * @param codeHash Hash of the agent's off-chain code
     * @param metadataHash IPFS hash of agent metadata
     */
    function registerAgent(
        address agentAddress,
        bytes32 codeHash,
        bytes32 metadataHash
    ) external whenNotPaused returns (uint256) {
        require(agentAddress != address(0), "AgentRegistry: zero address");
        require(agentIds[agentAddress] == 0, "AgentRegistry: already registered");
        require(codeHash != bytes32(0), "AgentRegistry: empty code hash");
        
        uint256 agentId = _nextAgentId++;
        
        agents[agentId] = Agent({
            id: agentId,
            codeHash: codeHash,
            status: AgentStatus.ACTIVE,
            metadataHash: metadataHash,
            lastUpdated: block.timestamp,
            owner: msg.sender
        });
        
        agentIds[agentAddress] = agentId;
        
        emit AgentRegistered(agentId, agentAddress, codeHash, msg.sender);
        emit AgentVerified(agentId, codeHash);
        
        return agentId;
    }
    
    /**
     * @notice Update agent code hash
     * @param agentId The agent ID to update
     * @param newCodeHash New code hash
     */
    function updateAgent(
        uint256 agentId,
        bytes32 newCodeHash
    ) external whenNotPaused onlyAgentOwner(agentId) {
        Agent storage agent = agents[agentId];
        require(agent.status != AgentStatus.BANNED, "AgentRegistry: agent banned");
        
        bytes32 oldCodeHash = agent.codeHash;
        agent.codeHash = newCodeHash;
        agent.status = AgentStatus.UPDATED;
        agent.lastUpdated = block.timestamp;
        
        emit AgentUpdated(agentId, oldCodeHash, newCodeHash);
        emit AgentVerified(agentId, newCodeHash);
    }
    
    /**
     * @notice Ban an agent
     * @param agentId The agent ID to ban
     * @param reason Reason for banning
     */
    function banAgent(
        uint256 agentId,
        string calldata reason
    ) external onlyOwner {
        Agent storage agent = agents[agentId];
        require(agent.id != 0, "AgentRegistry: agent not found");
        
        agent.status = AgentStatus.BANNED;
        agent.lastUpdated = block.timestamp;
        
        emit AgentBanned(agentId, reason);
    }
    
    /**
     * @notice Unban an agent
     * @param agentId The agent ID to unban
     */
    function unbanAgent(uint256 agentId) external onlyOwner {
        Agent storage agent = agents[agentId];
        require(agent.id != 0, "AgentRegistry: agent not found");
        require(agent.status == AgentStatus.BANNED, "AgentRegistry: not banned");
        
        agent.status = AgentStatus.ACTIVE;
        agent.lastUpdated = block.timestamp;
        
        emit AgentVerified(agentId, agent.codeHash);
    }
    
    // ===========================================
    // View Functions
    // ===========================================
    
    /**
     * @notice Get agent by ID
     */
    function getAgent(uint256 agentId) external view returns (Agent memory) {
        return agents[agentId];
    }
    
    /**
     * @notice Get agent by address
     */
    function getAgentByAddress(address agentAddress) external view returns (Agent memory) {
        uint256 agentId = agentIds[agentAddress];
        require(agentId != 0, "AgentRegistry: agent not found");
        return agents[agentId];
    }
    
    /**
     * @notice Check if agent is active
     */
    function isAgentActive(uint256 agentId) external view returns (bool) {
        return agents[agentId].status == AgentStatus.ACTIVE || 
               agents[agentId].status == AgentStatus.UPDATED;
    }
    
    /**
     * @notice Check if agent is active by address
     */
    function isAgentActiveByAddress(address agentAddress) external view returns (bool) {
        uint256 agentId = agentIds[agentAddress];
        if (agentId == 0) return false;
        return agents[agentId].status == AgentStatus.ACTIVE || 
               agents[agentId].status == AgentStatus.UPDATED;
    }
    
    /**
     * @notice Verify agent code hash
     */
    function verifyCodeHash(uint256 agentId, bytes32 codeHash) external view returns (bool) {
        return agents[agentId].codeHash == codeHash;
    }
    
    /**
     * @notice Get total registered agents
     */
    function totalAgents() external view returns (uint256) {
        return _nextAgentId - 1;
    }
    
    // ===========================================
    // Admin Functions
    // ===========================================
    
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "AgentRegistry: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // ===========================================
    // IAlexandros Implementation (stub)
    // ===========================================
    
    function validatePermission(
        bytes32,
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override {
        revert("AgentRegistry: use PermissionAuthority");
    }
}
