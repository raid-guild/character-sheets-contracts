#!/bin/bash
source .env

set -e

cat << "EOF"
                    ____                          __      ____                 _        _     
 /'\_/`\           /\  _`\                       /\ \    /\  _`\             /' \     /' \    
/\      \    _ __  \ \ \/\ \     __      __      \_\ \   \ \ \/\_\     __   /\_, \   /\_, \   
\ \ \__\ \  /\`'__\ \ \ \ \ \  /'__`\  /'__`\    /'_` \   \ \ \/_/_  /'__`\ \/_/\ \  \/_/\ \  
 \ \ \_/\ \ \ \ \/   \ \ \_\ \/\  __/ /\ \L\.\_ /\ \L\ \   \ \ \L\ \/\  __/    \ \ \    \ \ \ 
  \ \_\\ \_\ \ \_\    \ \____/\ \____\\ \__/.\_\\ \___,_\   \ \____/\ \____\    \ \_\    \ \_\
   \/_/ \/_/  \/_/     \/___/  \/____/ \/__/\/_/ \/__,_ /    \/___/  \/____/     \/_/     \/_/
***********************************************************************************************

EOF

if [[ $1 == "" || $2 == "" ]]
    then
        echo "Usage:"
        echo "  verify.sh [target environment] [contractName]"
        echo "    where target environment (required): gnosis / sepolia"
        echo "    where contractName (required): contract name you want to verify the action from"
        echo ""
        echo "Example:"
        echo "  verify.sh sepolia CharacterSheetsFactory"
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
        echo " Saved Address for $2 not found"
        read -p " Exit? (y/n):" CONFIRMATION
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
    echo " Chain Id not found"
    echo " Exiting script"
    exit 1
fi

API_KEY=$ETHERSCAN_API_KEY

if [[ $NETWORK == "gnosis" ]]; then
    API_KEY=$GNOSISSCAN_API_KEY
    export VERIFIER_URL="https://api.gnosisscan.io/api/"
fi

if [[ $2 == *"Implementation" ]]; then
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.25+commit.b61c2a91 --etherscan-api-key $API_KEY --num-of-optimizations 20000 $SAVED_ADDRESS src/implementations/$2.sol:$2 
elif [[ $2 == *"Adaptor" ]]; then
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.25+commit.b61c2a91 --etherscan-api-key $API_KEY --num-of-optimizations 20000 $SAVED_ADDRESS src/adaptors/$2.sol:$2 
elif [[ $2 == *"EligibilityModule" ]]; then
    CONSTRUCTOR_ARGS="00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000005302e302e31000000000000000000000000000000000000000000000000000000"
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.25+commit.b61c2a91 --etherscan-api-key $API_KEY --num-of-optimizations 20000 --constructor-args $CONSTRUCTOR_ARGS $SAVED_ADDRESS src/adaptors/hats-modules/$2.sol:$2 
else
    forge verify-contract --watch --chain-id $CHAIN_ID --compiler-version v0.8.25+commit.b61c2a91 --etherscan-api-key $API_KEY  --num-of-optimizations 20000 $SAVED_ADDRESS src/$2.sol:$2
fi

echo "end verification"
exit 0
