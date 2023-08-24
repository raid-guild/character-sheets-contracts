#!/bin/bash
source .env

set -e

if [[ $1 == "" || $2 == "" || $3 == "" ]]
    then
        echo "Usage:"
        echo "  execute.sh [target environment] [contractName] [actionName]"
        echo "    where target environment (required): mainnet / testnet / sandbox"
        echo "    where contractName (required): contract name you want to execute the action from"
        echo "    where actionName (required): action name you want to execute"
        echo ""
        echo "Example:"
        echo "  execute.sh sandbox RoundFactory RoundCreate"
        exit 1
fi

NETWORK=$(node script/helpers/readNetwork.js $1)
if [[ $NETWORK == "" ]]
    then
        echo "No network found for $1 environment target in addresses.json. Terminating"
        exit 1
fi


if [[ $PRIVATE_KEY == "" && $1 == "anvil" ]]
    then
        PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
fi

CALLDATA=$(cast calldata "run(string)" $1)
PRIVATE_KEY=$PRIVATE_KEY forge script script/$2.s.sol:Execute$3 -s $CALLDATA --rpc-url $NETWORK

read -p "Please verify the data and confirm the execution (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Executing..."

        FORGE_OUTPUT=$(PRIVATE_KEY=$PRIVATE_KEY forge script script/$2.s.sol:Execute$3 -s $CALLDATA --rpc-url $NETWORK --broadcast)
        echo "$FORGE_OUTPUT"

        DEPLOYED_ADDRESS=$(echo "$FORGE_OUTPUT" | grep "Contract Address:" | sed -n 's/.*: \(0x[0-9a-hA-H]\{40\}\)/\1/p')

        if [[ $DEPLOYED_ADDRESS != "" ]]
            then
                echo "Found Deployed address of $2 in foundry logs: "
                echo $DEPLOYED_ADDRESS
                exit 1
        fi
    else
        echo "Deployment cancelled. Execution terminated."
fi
