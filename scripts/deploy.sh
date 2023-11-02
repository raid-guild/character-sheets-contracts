#!/bin/bash
source .env

set -e

cat << "EOF"
                    ____                          __      ____                 _        _     
 /'\_/`\           /\  _ `\                      /\ \    /\  _` \            /' \     /' \    
/\      \    _ __  \ \ \/\ \     __      __      \_\ \   \ \ \/\_\     __   /\_, \   /\_, \   
\ \ \__\ \  /\`'__\ \ \ \ \ \  /'__`\  /'__`\    /'_` \   \ \ \/_/_  /'__`\ \/_/\ \  \/_/\ \  
 \ \ \_/\ \ \ \ \/   \ \ \_\ \/\  __/ /\ \L\.\_ /\ \L\ \   \ \ \L\ \/\  __/    \ \ \    \ \ \ 
  \ \_\\ \_\ \ \_\    \ \____/\ \____\\ \__/.\_\\ \___,_\   \ \____/\ \____\    \ \_\    \ \_\
   \/_/ \/_/  \/_/     \/___/  \/____/ \/__/\/_/ \/__,_ /    \/___/  \/____/     \/_/     \/_/
*************************************************************************************************
                                                                                          
EOF

if [[ $1 == "" || $2 == "" || ($3 != "--verify" && $3 != "--force" && $3 != "") || ($4 != "--verify" && $4 != "--force" && $4 != "") ]]; then
    echo "Usage:"
    echo "  deploy.sh [target environment] [contractName]"
    echo "    where target environment (required): mainnet / testnet"
    echo "    where contractName (required): contract name you want to deploy"
    echo "    --verify: if you want to verify the deployed source code"
    echo "                   [constructor-args] are ABI-Encoded for verification (see 'cast abi-encode' docs)"
    echo "    --force: if you want to force the deployment of a contract that has already been deployed"
    echo ""
    echo "Example:"
    echo "  deploy.sh testnet CharacterSheetsFactory"
    exit 1
fi

NETWORK=$(node scripts/helpers/readNetwork.js $1)
if [[ $NETWORK == "" ]]; then
    echo "No network found for $1 environment target in addresses.json. Terminating"
    exit 1
fi

echo "Deploying $2 to $1"

SAVED_ADDRESS=$(node scripts/helpers/readAddress.js $1 $2)

FORCE=false
if [[ $3 == "--force" || $4 == "--force" ]]; then
    FORCE=true
fi

if [[ $SAVED_ADDRESS != "" && $FORCE == false ]]; then
    echo "Found $2 already deployed on $1 at: $SAVED_ADDRESS"
    read -p "Should we redeploy it? (y/n):" CONFIRMATION
    if [[ $CONFIRMATION != "y" && $CONFIRMATION != "Y" ]]
        then
        echo "Deployment skipped. deploying next contract......"
        exit 0
    fi
fi

if [[ $1 == "anvil" ]]; then
   PRIVATE_KEY="ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
   NETWORK="http://localhost:8545"
fi

CALLDATA=$(cast calldata "run(string)" $1)

CONFIRMATION="n"

if [[ $FORCE == false ]]; then
    PRIVATE_KEY=$PRIVATE_KEY forge script scripts/$2.s.sol:Deploy$2 -s $CALLDATA --rpc-url $NETWORK
    read -p "Please verify the data and confirm the deployment (y/n):" CONFIRMATION
fi

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" || $FORCE == true ]]; then
    FORGE_OUTPUT=$(PRIVATE_KEY=$PRIVATE_KEY forge script scripts/$2.s.sol:Deploy$2 --broadcast -s $CALLDATA --rpc-url $NETWORK)
    DEPLOYED_ADDRESS=$(echo "$FORGE_OUTPUT" | grep "Contract Address:" | sed -n 's/.*: \(0x[0-9a-hA-H]\{40\}\)/\1/p')
    TX_HASH=$(echo "$FORGE_OUTPUT" | grep "Hash:" | head -1 | sed -n 's/.*: \(0x[0-9a-hA-H]\{64\}\)/\1/p')
else
    echo "Deployment skipped..."
    exit 0
fi

echo "Deployment completed: $DEPLOYED_ADDRESS"
echo "Transaction hash: $TX_HASH"
echo ""

node scripts/helpers/saveAddress.js $1 $2 $DEPLOYED_ADDRESS

VERIFY=false
if [[ $3 == "--verify" || $4 == "--verify" ]]; then
    VERIFY=true
fi

if [[ $VERIFY == false || $NETWORK == "anvil" ]]; then
    echo "Skipping verification"
    exit 0
fi

CHAIN_ID=$(node scripts/helpers/readChainId.js $1)

if [[ $CHAIN_ID == "" ]]; then
    echo " Chain Id not found"
    echo " Exiting script"
    exit 1
fi

echo ""

TX_BLOCK_NUMBER=$(cast receipt $TX_HASH --rpc-url $NETWORK | grep "blockNumber" | sed -n 's/blockNumber\s*\([0-9]\)/\1/p')

BLOCK_NUMBER=$(cast block-number --rpc-url $NETWORK)
CONFIRMATIONS=$(($BLOCK_NUMBER - $TX_BLOCK_NUMBER))
while [[ $CONFIRMATIONS -lt 1 ]]; do
    echo "Waiting for transaction to be mined up to 1 confirmation..."
    sleep 10
    BLOCK_NUMBER=$(cast block-number --rpc-url $NETWORK)
    CONFIRMATIONS=$(($BLOCK_NUMBER - $TX_BLOCK_NUMBER))
done

echo ""

API_KEY=$ETHERSCAN_API_KEY

if [[ $NETWORK == "gnosis" ]]; then
    API_KEY=$GNOSISSCAN_API_KEY
    export VERIFIER_URL="https://api.gnosisscan.io/api/"
fi


if [[ $2 == *"Implementation" ]]; then
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.20+commit.a1b79de6 --etherscan-api-key $API_KEY --num-of-optimizations 20000 $DEPLOYED_ADDRESS src/implementations/$2.sol:$2 
elif [[ $2 == *"Adaptor" ]]; then
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.20+commit.a1b79de6 --etherscan-api-key $API_KEY --num-of-optimizations 20000 $DEPLOYED_ADDRESS src/adaptors/$2.sol:$2 
elif [[ $2 == *"EligibilityModule" ]]; then
    CONSTRUCTOR_ARGS="0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b76657273696f6e20302e31000000000000000000000000000000000000000000"
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.20+commit.a1b79de6 --etherscan-api-key $API_KEY --num-of-optimizations 20000 --constructor-args $CONSTRUCTOR_ARGS $DEPLOYED_ADDRESS src/adaptors/hats-modules/$2.sol:$2 
else
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.20+commit.a1b79de6 --etherscan-api-key $API_KEY  --num-of-optimizations 20000 $DEPLOYED_ADDRESS src/$2.sol:$2
fi

echo "end verification"
exit 0
