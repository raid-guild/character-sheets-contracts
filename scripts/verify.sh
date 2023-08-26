#!/bin/bash
source .env

set -e

if [[ $1 == "" || $2 == "" ]]
    then
        echo "Usage:"
        echo "  verify.sh [target environment] [contractName] [actionName]"
        echo "    where target environment (required): gnosis / sepolia"
        echo "    where contractName (required): contract name you want to execute the action from"
        echo "    where actionName (required): action name you want to execute"
        echo ""
        echo "Example:"
        echo "  execute.sh sepolia CharacterSheetsFactory create"
        exit 1
fi

NETWORK=$(node scripts/helpers/readNetwork.js $1)
if [[ $NETWORK == "" ]]
    then
        echo "No network found for $1 environment target in addresses.json. Terminating"
        exit 1
fi



if [[ $PRIVATE_KEY == "" && $1 == "anvil" ]]
    then
        PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
fi

SAVED_ADDRESS=$(node scripts/helpers/readAddress.js $1 $2)

if [[ $SAVED_ADDRESS == "" ]]
    then
        echo "Saved Address for $2 not found"
        read -p "Exit? (y/n):" CONFIRMATION
        if [[ $CONFIRMATION != "y" && $CONFIRMATION != "Y" ]]
            then
            echo "Deployment cancelled. Execution terminated."
            exit 1
        fi
fi

CALLDATA=$(cast calldata "run(string)" $1)

CHAIN_ID=$(node scripts/helpers/readChainId.js $1)

if [[ CHAIN_ID == "" ]]
then
    echo "Chain Id not found"
    echo "Exiting script"
    exit 1
fi

if [[ $2 == *"Implementation"* ]]
then
    # FORGE_OUTPUT=$(forge verify-contract $SAVED_ADDRESS src/implementations/$2.sol:$2\ --chain-id $CHAIN_ID)
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.20+commit.a1b79de6 --etherscan-api-key $ETHERSCAN_API_KEY --num-of-optimizations 1000000 $SAVED_ADDRESS src/implementations/$2.sol:$2 
else
    FORGE_OUTPUT=$(forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.20+commit.a1b79de6 --etherscan-api-key $ETHERSCAN_API_KEY  --num-of-optimizations 1000000 $SAVED_ADDRESS src/$2.sol:$2)
fi

echo "end verification"
# SUCCESS=$(FORGE_OUTPUT | grep "success")


# PRIVATE_KEY=$PRIVATE_KEY forge verify-contract $SAVED_ADDRESS /$2.s.sol:Execute$3 -s $CALLDATA --rpc-url $NETWORK

# read -p "Please verify the data and confirm the execution (y/n):" CONFIRMATION

# if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
#     then
#         echo "Executing..."

#         FORGE_OUTPUT=$(PRIVATE_KEY=$PRIVATE_KEY forge script script/$2.s.sol:Execute$3 -s $CALLDATA --rpc-url $NETWORK --broadcast)
#         echo "$FORGE_OUTPUT"

#         DEPLOYED_ADDRESS=$(echo "$FORGE_OUTPUT" | grep "Contract Address:" | sed -n 's/.*: \(0x[0-9a-hA-H]\{40\}\)/\1/p')

#         if [[ $DEPLOYED_ADDRESS != "" ]]
#             then
#                 echo "Found Deployed address of $2 in foundry logs: "
#                 echo $DEPLOYED_ADDRESS
#                 exit 1
#         fi
#     else
#         echo "Deployment cancelled. Execution terminated."
# fi