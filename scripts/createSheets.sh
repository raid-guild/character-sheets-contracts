#!/bin/bash
source .env

set -e



function makeNewDMList(){
network=$1
while true; do
    read -p "Please enter a dungeon master address: " INPUT
    echo "================================================"
    read -p "Would you like to enter another address? (y/n) " CONFIRMATION

    DUNGEON_MASTERS+=($INPUT)

    if [[ $CONFIRMATION == "n" || $CONFIRMATION == "N" ]]
        then 
        break
    fi



done
for item in "${DUNGEON_MASTERS[@]}"; do
node scripts/helpers/saveCreationData.js $network DungeonMasters $item
done
}


# if [[ $1 == "" || $2 == "" || $3 == "" || $4 == "" || $5 == "" ]]
if [[ $1 == "" ]]
    then
        echo "Usage:"
        echo "  createSheets.sh [target environment] [[dungeon masters]] [characterSheets base uri] [experience base uri] [classes base uri]"
        echo "    where target environment (required): gnosis / sepolia"
        echo "    an array of addresses that will have the dungeon master permission, min 1"
        echo "    the base uri for the character sheets contract"
        echo "    the base uri for the experience and items contract"
        echo "    the base uri for the classes contract"
        echo ""
        echo "Example:"
        echo "  createSheets.sh sepolia [ 0xethereumAddressesHave40Characters , 0xsoWouldThisOneHypothetically ] ipfs://fybeidlkqhddsjrdue7y3dy27pu5d7ydyemcls4z24szlyik3we7vqvam/character-sheets ipfs://bafybeidlkqhddsjrdue7y3dy27pu5d7ydyemcls4z24szlyik3we7vqvam/experience ipfs://bafybeidlkqhddsjrdue7y3dy27pu5d7ydyemcls4z24szlyik3we7vqvam/classes"
        echo $1 $2 $3 $4 $5
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


DUNGEON_MASTERS=$(node scripts/helpers/readAddress.js $1 DungeonMasters)

DMLENGTH=$(echo -n "$DUNGEON_MASTERS"| sed 's/[][]//g; s/,/ /g' | wc -w)


if [[ $DMLENGTH != 0 ]]
    then
        echo "Stored Dungeon masters have been found."
        read -p "Would you like to create a new Dungeon Masters List? (y/n) "  MAKENEWLIST
        if [[ $MAKENEWLIST == "y" || $MAKENEWLIST == "Y" ]]
            then
                node scripts/helpers/saveCreationData.js $1 DungeonMasters delete
                makeNewDMList $1
        fi
    else
    makeNewDMList $1
fi

CHARACTERSHEETSBASEURI=$(node scripts/helpers/readAddress.js $1 CharacterSheetsBaseUri)

if [[ $CHARACTERSHEETSBASEURI != '' ]]
then
echo "Character Sheets base uri detected."
read -p "Would you like to insert a new uri? (y/n)" SHEETSCONF
    if [[ $SHEETSCONF == "y" || $SHEETSCONF == "Y" ]]
        then
        read -p "Enter new Character Sheets base uri: " NEWSHEETSURI
        node scripts/helpers/saveCreationData.js $1 CharacterSheetsBaseUri $NEWSHEETSURI
    fi
    else        
        read -p "Enter new Character Sheets base uri: " NEWSHEETSURI
        node scripts/helpers/saveCreationData.js $1 CharacterSheetsBaseUri $NEWSHEETSURI
fi

EXPERIENCEBASEURI=$(node scripts/helpers/readAddress.js $1 ExperienceBaseUri)

if [[ $EXPERIENCEBASEURI != '' ]]
then
echo "Experience and Items base uri detected."
read -p "Would you like to insert a new uri? (y/n)" EXPCONF
    if [[ $EXPCONF == "y" || $EXPCONF == "Y" ]]
        then
        read -p "Enter new Items and Experience base uri: " NEWEXPURI
        node scripts/helpers/saveCreationData.js $1 ExperienceBaseUri $NEWEXPURI
    fi
    else        
        read -p "Enter new Items and Experience base uri: " NEWEXPURI
        node scripts/helpers/saveCreationData.js $1 ExperienceBaseUri $NEWEXPURI
fi

CLASSESBASEURI=$(node scripts/helpers/readAddress.js $1 ClassesBaseUri)

if [[ $CLASSESBASEURI != '' ]]
then
echo "Classes base uri detected."
read -p "Would you like to insert a new uri? (y/n):" CLASSCONF
    if [[ $CLASSCONF == "y" || $CLASSCONF == "Y" ]]
        then
        read -p "Enter new Classes base uri: " NEWCLASSURI
        node scripts/helpers/saveCreationData.js $1 ClassesBaseUri $NEWCLASSURI
    fi
    else        
        read -p "Enter new Classes base uri: " NEWCLASSURI
        node scripts/helpers/saveCreationData.js $1 ClassesBaseUri $NEWCLASSURI
fi


CALLDATA=$(cast calldata "run(string)" $1)
PRIVATE_KEY=$PRIVATE_KEY forge script scripts/CharacterSheetsFactory.s.sol:Create -s $CALLDATA --rpc-url $NETWORK

read -p "Please verify the data and confirm the creation of a new game (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Executing..."

        FORGE_OUTPUT=$(PRIVATE_KEY=$PRIVATE_KEY forge script scripts/CharacterSheetsFactory.s.sol:Create -s $CALLDATA --rpc-url $NETWORK --broadcast)
        echo "$FORGE_OUTPUT"

        DEPLOYED_ADDRESSES=$(echo "$FORGE_OUTPUT" | grep -oEi 'New contracts created.*0x[a-fA-F0-9]{40}' | grep -oEi '*0x[a-fA-F0-9]{40}')

        if [[ $DEPLOYED_ADDRESSES != "" ]]
            then
                echo "Found Deployed address of new contracts in foundry logs: "
                echo "$DEPLOYED_ADDRESSES"
                
                mapfile -t ADDRESSES_ARRAY <<< "$DEPLOYED_ADDRESSES"
                #TODO MAKE THIS WORK
                echo "================================"
                node scripts/helpers/saveCreationData.js $1 CreatedCharacterSheet "${ADDRESSES_ARRAY[0]}"
                node scripts/helpers/saveCreationData.js $1 CreatedExperienceAndItems "${ADDRESSES_ARRAY[1]}"
                node scripts/helpers/saveCreationData.js $1 CreatedClasses "${ADDRESSES_ARRAY[2]}"

        fi
    else
        echo "Deployment cancelled. Execution terminated."
fi


echo "Contracts created succesfully"