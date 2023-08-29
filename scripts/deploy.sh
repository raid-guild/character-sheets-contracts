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

if [[ $1 == "" || $2 == "" || ($3 != "--verify" && $3 != "")]]
    then
        echo "Usage:"
        echo "  deploy.sh [target environment] [contractName] --verify-only [constructor-args]"
        echo "    where target environment (required): mainnet / testnet"
        echo "    where contractName (required): contract name you want to deploy"
        echo "    --verify: if you want to verify the deployed source code"
        echo "                   [constructor-args] are ABI-Encoded for verification (see 'cast abi-encode' docs)"
        echo ""
        echo "Example:"
        echo "  deploy.sh testnet CharacterSheetsFactory"
        exit 1
fi

NETWORK=$(node scripts/helpers/readNetwork.js $1)
if [[ $NETWORK == "" ]]
    then
        echo "No network found for $1 environment target in addresses.json. Terminating"
        exit 1
fi

SAVED_ADDRESS=$(node scripts/helpers/readAddress.js $1 $2)

echo $SAVED_ADDRESS

if [[ $SAVED_ADDRESS != "" ]]
    then
        echo "Found $2 already deployed on $1 at: $SAVED_ADDRESS"
        read -p "Should we redeploy it? (y/n):" CONFIRMATION
        if [[ $CONFIRMATION != "y" && $CONFIRMATION != "Y" ]]
            then
            echo "Deployment cancelled. Execution terminated."
            exit 1
        fi
fi

if [[ $PRIVATE_KEY == "" && $1 == "anvil" ]]
    then
      PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
fi

CALLDATA=$(cast calldata "run(string)" $1)
PRIVATE_KEY=$PRIVATE_KEY forge script scripts/$2.s.sol:Deploy$2 -s $CALLDATA --rpc-url $NETWORK

read -p "Please verify the data and confirm the deployment (y/n):" CONFIRMATION
if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
then
FORGE_OUTPUT=$(forge script scripts/$2.s.sol:Deploy$2 --broadcast -s $CALLDATA --rpc-url $NETWORK)

DEPLOYED_ADDRESS=$(echo "$FORGE_OUTPUT" | grep "Contract Address:" | sed -n 's/.*: \(0x[0-9a-hA-H]\{40\}\)/\1/p')
fi


        node scripts/helpers/saveAddress.js $1 $2 $DEPLOYED_ADDRESS



    echo "Deployment completed: $DEPLOYED_ADDRESS"