#!/bin/bash
# Alexandros Protocol - Quick Deploy Script
# Usage: ./deploy.sh [--verify]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Alexandros Protocol Deployment${NC}"
echo -e "${GREEN}======================================${NC}"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo ""
    echo "Please create a .env file with:"
    echo "  PRIVATE_KEY=your_private_key"
    echo "  ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc"
    echo "  ARBISCAN_API_KEY=your_api_key (optional)"
    echo ""
    echo "You can copy from .env.example:"
    echo "  cp .env.example .env"
    exit 1
fi

# Load environment
source .env

# Validate required vars
if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "your_private_key_here" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$ARBITRUM_SEPOLIA_RPC_URL" ]; then
    ARBITRUM_SEPOLIA_RPC_URL="https://sepolia-rollup.arbitrum.io/rpc"
fi

# Check for --verify flag
VERIFY_FLAG=""
if [ "$1" = "--verify" ]; then
    if [ -z "$ARBISCAN_API_KEY" ] || [ "$ARBISCAN_API_KEY" = "your_arbiscan_api_key" ]; then
        echo -e "${YELLOW}Warning: ARBISCAN_API_KEY not set, skipping verification${NC}"
    else
        VERIFY_FLAG="--verify --etherscan-api-key $ARBISCAN_API_KEY"
        echo -e "${GREEN}Will verify contracts on Arbiscan${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}Network: Arbitrum Sepolia (Chain ID: 421614)${NC}"
echo -e "${YELLOW}RPC: $ARBITRUM_SEPOLIA_RPC_URL${NC}"
echo ""

# Simulate first
echo -e "${GREEN}Step 1: Simulating deployment...${NC}"
forge script script/Deploy.s.sol:DeployAlexandros \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

echo ""
echo -e "${GREEN}Simulation successful!${NC}"
echo ""

# Ask for confirmation
read -p "Proceed with actual deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
fi

# Deploy
echo ""
echo -e "${GREEN}Step 2: Broadcasting transactions...${NC}"
forge script script/Deploy.s.sol:DeployAlexandros \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --broadcast \
    $VERIFY_FLAG \
    --private-key $PRIVATE_KEY

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Check broadcast folder for deployment addresses:"
echo "  cat broadcast/Deploy.s.sol/421614/run-latest.json"
echo ""
echo "View on Arbiscan: https://sepolia.arbiscan.io"
echo ""
