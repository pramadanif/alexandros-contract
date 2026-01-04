# Alexandros Smart Contract Deployment Guide

## Prerequisites

1. **Private Key** dengan ETH di Arbitrum Sepolia
2. **Arbiscan API Key** untuk contract verification (optional tapi recommended)

### Get Arbitrum Sepolia ETH

1. Go to [Arbitrum Sepolia Faucet](https://faucet.quicknode.com/arbitrum/sepolia)
2. Or use [Alchemy Faucet](https://www.alchemy.com/faucets/arbitrum-sepolia)
3. Request test ETH to your wallet

### Get Arbiscan API Key (Optional)

1. Go to [Arbiscan](https://arbiscan.io/) → Sign Up/Login
2. Go to API Keys section
3. Create new API key

## Setup

### 1. Create .env file

```bash
cd alexandros-contract
cp .env.example .env
```

### 2. Edit .env file

```env
# Your private key (WITHOUT 0x prefix)
PRIVATE_KEY=your_64_char_hex_private_key_here

# RPC URLs (these are public, can keep as is)
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc

# Arbiscan API Key for verification (optional)
ARBISCAN_API_KEY=your_arbiscan_api_key_here
```

⚠️ **SECURITY WARNING**: Never commit your `.env` file!

## Deployment Commands

### Deploy WITHOUT verification (faster, no API key needed)

```bash
source .env

forge script script/Deploy.s.sol:DeployAlexandros \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --broadcast \
    --private-key $PRIVATE_KEY
```

### Deploy WITH verification (recommended for production)

```bash
source .env

forge script script/Deploy.s.sol:DeployAlexandros \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ARBISCAN_API_KEY \
    --private-key $PRIVATE_KEY
```

### Simulation (dry-run, no broadcast)

```bash
source .env

forge script script/Deploy.s.sol:DeployAlexandros \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

## Post-Deployment

After successful deployment, you'll see output like:

```
== Logs ==
  Deploying Alexandros Protocol...
  AgentRegistry deployed at: 0x...
  PermissionAuthority deployed at: 0x...
  Deployment complete!
```

### Update Other Components

1. **Indexer** (`alexandros-indexer/.env`):
   ```env
   ENVIO_ALEXANDROS_ADDRESS_SEPOLIA=0x_PermissionAuthority_Address
   ENVIO_REGISTRY_ADDRESS_SEPOLIA=0x_AgentRegistry_Address
   ```

2. **Backend** (`alexandros-be/.env`):
   ```env
   CONTRACT_ADDRESS_SEPOLIA=0x_PermissionAuthority_Address
   REGISTRY_ADDRESS_SEPOLIA=0x_AgentRegistry_Address
   ```

3. **Frontend** (`alexandros-fe/.env.local`):
   ```env
   NEXT_PUBLIC_CONTRACT_ADDRESS_SEPOLIA=0x_PermissionAuthority_Address
   NEXT_PUBLIC_REGISTRY_ADDRESS_SEPOLIA=0x_AgentRegistry_Address
   ```

## Network Info

| Network | Chain ID | RPC URL |
|---------|----------|---------|
| Arbitrum Sepolia | 421614 | https://sepolia-rollup.arbitrum.io/rpc |
| Block Explorer | - | https://sepolia.arbiscan.io |

## Troubleshooting

### Error: "insufficient funds"
→ Get more Arbitrum Sepolia ETH from faucet

### Error: "nonce too low"
→ Add `--slow` flag to deployment command

### Error: "contract verification failed"
→ Check Arbiscan API key is valid
→ Try manual verification at sepolia.arbiscan.io

## Quick Deploy Script

```bash
#!/bin/bash
# deploy.sh

set -e

echo "Loading environment..."
source .env

echo "Simulating deployment..."
forge script script/Deploy.s.sol:DeployAlexandros \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

read -p "Proceed with actual deployment? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deploying..."
    forge script script/Deploy.s.sol:DeployAlexandros \
        --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
        --broadcast \
        --private-key $PRIVATE_KEY
    echo "Done!"
fi
```

Save as `deploy.sh` and run: `chmod +x deploy.sh && ./deploy.sh`
