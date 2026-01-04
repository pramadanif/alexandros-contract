# Alexandros Smart Contracts

Foundry project untuk Alexandros Protocol smart contracts.

## Prerequisites

- [Foundry](https://getfoundry.sh/)
- Private key dengan ETH di Arbitrum Sepolia

## Setup

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install

# Copy environment file
cp .env.example .env
# Edit .env dengan private key dan RPC URL
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## Deploy ke Arbitrum Sepolia

```bash
# Load environment variables
source .env

# Deploy
forge script script/Deploy.s.sol:DeployAlexandros \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

## Verify Contract

```bash
forge verify-contract \
    --chain-id 421614 \
    --compiler-version v0.8.20 \
    <CONTRACT_ADDRESS> \
    contracts/AgentRegistry.sol:AgentRegistry \
    --etherscan-api-key $ARBISCAN_API_KEY
```

## Contracts

| Contract | Description |
|----------|-------------|
| `AgentRegistry` | ERC-8004 compatible agent registry |
| `PermissionAuthority` | Core permission management |
| `IAlexandros` | Interface definitions |

## Architecture

```
User (EOA/Smart Account)
    │
    ├── grantPermission() ──► PermissionAuthority
    │                              │
    │                              └── isAgentActive() ──► AgentRegistry
    │
    └── Smart Account Execute
            │
            └── validatePermission() ──► PermissionAuthority
                                              │
                                              └── Emit ExecutionAuthorized
```

## Events

- `PermissionGranted(permissionId, user, agent, target, expiresAt)`
- `PermissionRevoked(permissionId, user, reason)`
- `PermissionExpired(permissionId, user)`
- `ExecutionAuthorized(permissionId, agent, target, selector, value)`
- `AgentVerified(agentId, codeHash)`
- `AgentBanned(agentId, reason)`

## Get Testnet ETH

- [Arbitrum Sepolia Faucet](https://faucet.quicknode.com/arbitrum/sepolia)
- [Alchemy Arbitrum Sepolia](https://sepoliafaucet.com/)
# alexandros-contract
