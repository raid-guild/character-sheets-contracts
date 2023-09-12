#!/bin/bash
source .env

set -e                                                                                                           
cat << "EOF"
                    ____                          __      ____                 _        _     
 /'\_/`\           /\  _ `\                      /\ \    /\  _ `\            /' \     /' \    
/\      \    _ __  \ \ \/\ \     __      __      \_\ \   \ \ \/\_\     __   /\_, \   /\_, \   
\ \ \__\ \  /\`'__\ \ \ \ \ \  /'__`\  /'__`\    /'_` \   \ \ \/_/_  /'__`\ \/_/\ \  \/_/\ \  
 \ \ \_/\ \ \ \ \/   \ \ \_\ \/\  __/ /\ \L\.\_ /\ \L\ \   \ \ \L\ \/\  __/    \ \ \    \ \ \ 
  \ \_\\ \_\ \ \_\    \ \____/\ \____\\ \__/.\_\\ \___,_\   \ \____/\ \____\    \ \_\    \ \_\
   \/_/ \/_/  \/_/     \/___/  \/____/ \/__/\/_/ \/__,_ /    \/___/  \/____/     \/_/     \/_/
*************************************************************************************************
*************************************************************************************************

EOF

function makeNewRequiredItemList(){
while true; do

    
        read -p "Please enter the name of a required ITEM: " REQUIREDITEMNAME
        read -p "Please enter the number of this item you'd like to require: " REQUIREDITEMNUMBER
    
        
        local REQUIREDITEM+="$REQUIREDITEMNAME:$REQUIREDITEMNUMBER*"        
        read -p "Would you like to enter another ITEM REQUIREMENT? (y/n) " CONFIRMATION

    

    if [[ $CONFIRMATION == "n" || $CONFIRMATION == "N" ]]
        then 
            break
    fi
done
    echo "$REQUIREDITEM"

}

function makeNewRequiredClassesList(){
while true; do
    
        read -p "Please enter the name of a required CLASS: " REQUIREDCLASSNAME
    
    
    local REQUIREDCLASSES+="$REQUIREDCLASSNAME:"

        read -p "Would you like to enter another CLASS REQUIREMENT? (y/n) " CONFIRMATION

    

    if [[ $CONFIRMATION == "n" || $CONFIRMATION == "N" ]]
        then 
            break
    fi
    done
    echo "$REQUIREDCLASSES"
}

function makeNewAddressMerkle(){
    while true; do

        read -p "Please enter a whitelisted ADDRESS: " MERKLEADDRESS
        read -p "Please enter the number of this Item this address can claim: " MERKLENUMBER

    local MERKLEDATA+="$MERKLEADDRESS:$MERKLENUMBER*"

        read -p "Would you like to enter another WHITELIST ADDRESS? (y/n) " CONFIRMATION

    

    if [[ $CONFIRMATION == "n" || $CONFIRMATION == "N" ]]
        then 
            break
    fi
    done
    echo "$MERKLEDATA"

}


if [[ $1 == "" ]]
    then
        echo "Usage:"
        echo "  execute.sh [target environment]"
        echo "    where target environment (required): gnosis / sepolia"
        echo ""
        echo "Example:"
        echo "  execute.sh sepolia"
        exit 1
fi

NETWORK=$(node scripts/helpers/readNetwork.js $1)

echo 

if [[ $NETWORK == "" ]]
    then
        echo "No network found for $1 environment target in addresses.json. Terminating"
        exit 1
fi


if [[ $PRIVATE_KEY == "" && $1 == "anvil" ]]
    then
        PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
fi

echo "Please Select a Contract Interaction:"
echo "---------------------------------------------------------------"
echo "1: Create new class/classes"
echo "2: Create new Item/items"
echo "3: Roll a Character sheet"
echo "4: EXIT"
read -p "Enter your selection: " MENU_SELECTION


if [[ $MENU_SELECTION == 1 ]]
    then
    clear
    cat << "EOF"
  ### # # ####     ### #    ##    ######    ### #            ### #   #         ##      ### #    ### #  
 ##  #   ##   #   ##  #    ## #     #      ##  #            ##  #   ##        ## #    ##  #    ##  #   
##       ##   #  ##       ##   #   ##     ##               ##       ##       ##   #   ##       ##      
##       #####   ####     ######   ##     ####             ##       ##       ######    ####     ####   
##       ## #    ##       ##   #   ##     ##               ##       ##       ##   #      ###      ###  
##   #   ##  #   ##   #   ##   #   ##  #  ##   #           ##   #   ##    #  ##   #   #   ##   #   ##  
### ##   #   ##  ### ##   #    #   ### #  ### ##           ### ##   ###  #   #    #   ## ###   ## ###  
 #### # #     #   #### # #    ###   ###    #### #           #### # # #####  #    ### # ####   # ####   
*******************************************************************************************************
EOF

CONTRACT="ClassesImplementation"
CREATEDCLASSES=$(node scripts/helpers/readAddress.js $1 CreatedClasses)
    if [[ $CREATEDCLASSES != "" ]]
        then
        echo ""
            echo "Deployed Classes Contract detected at: $CREATEDCLASSES"
            echo "-------------------------------------------------------------------------------------"
            read -p "Would you like to create a new class at this address? (y/n) " NEWCLASSCONF

            if [[ $NEWCLASSCONF == "y" || $NEWCLASSCONF == "Y" ]]
                then
                    read -p "Please enter the name for your new class: " NEWCLASSNAME
                    read -P "Would you like Characters to be able to claim this class? (y/n) " NEWCLAIM
                    read -p "Please enter a URI for your new class (leave blank for default): " NEWURI
                    JSINPUT="$NEWCLASSNAME;NEWCLAIM;$NEWURI"
            SAVE_DATA=$(node scripts/helpers/saveExecutionData.js $1 Classes $JSINPUT)
            echo "$SAVE_DATA"
            INDEXOFNEWITEM=$(echo "$SAVE_DATA" | grep -oE '[[:digit:]]' | tr -d '\n' )
            CALLDATA=$(cast calldata "run(string,string)" $1 $INDEXOFNEWITEM);
            FORGE_OUTPUT=$(forge script scripts/$CONTRACT.s.sol:Execute$CONTRACT -s $CALLDATA --rpc-url $NETWORK)
            echo "$FORGE_OUTPUT"
            else
            echo "Please deploy new contracts or enter neww deployed address into addresses.json"
            exit 1
            fi
        else
        echo "No deployed classes contract detected"
        exit 1
    fi
      

elif [[ $MENU_SELECTION == 2 ]]
    then

                clear
cat << "EOF"
  ### # # ####     ### #    ##    ######    ### #            #    ######    ### #   #   #  
 ##  #   ##   #   ##  #    ## #     #      ##  #            ##      #      ##  #   ### ##  
##       ##   #  ##       ##   #   ##     ##                ##     ##     ##       ######  
##       #####   ####     ######   ##     ####              ##     ##     ####     ## # #  
##       ## #    ##       ##   #   ##     ##                ##     ##     ##       ##   #  
##   #   ##  #   ##   #   ##   #   ##  #  ##   #            ##     ##  #  ##   #   ##   #  
### ##   #   ##  ### ##   #    #   ### #  ### ##            #      ### #  ### ##   #    #  
 #### # #     #   #### # #    ###   ###    #### #          #        ###    #### # #    ###
 *******************************************************************************************
EOF

    CONTRACT="ItemsImplementation"
    CREATEDEXPERIENCEANDITEMS=$(node scripts/helpers/readAddress.js $1 CreatedExperienceAndItems)
    if [[ $CREATEDEXPERIENCEANDITEMS != "" ]]
        then
        echo ""
            echo "Deployed Experience and Items contract detected at: $CREATEDEXPERIENCEANDITEMS"
            echo "-------------------------------------------------------------------------"
            read -p "Would you like to create a new Item at this address? (y/n) " CONFIRMATION
            
            if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
                then
                read -p "Please enter the item's NAME: " ITEMNAME
                read -p "Please enter the max supply of this item: " MAXSUPPLY
                read -p "Please enter the image URI for this item: " IMAGEURI
                read -p "Is this item soulbound? (y/n) " SOULBOUND
                
                    if [[ $SOULBOUND == "y" || $SOULBOUND == 'Y' ]]
                        then
                            SOULBOUND="true"
                            else
                                SOULBOUND="false"
                    fi
                
                read -p "Would you like to make a list of items Required to claim this item? (y/n) " REQUIREDITEMS
                
                if [[ $REQUIREDITEMS == "y" || $REQUIREDITEMS == "Y" ]]
                    then

                    clear
                        echo ""
                        cat << "EOF"
  #    ######    ### #   #   #           # ####     ### #   ##    ##    #   #    # ####     ### #   #   #    ### #   #   #  ######    ### #  
 ##      #      ##  #   ### ##            ##   #   ##  #   ## #    #   #   ##     ##   #   ##  #   ### ##   ##  #   ##   #    #      ##  #   
 ##     ##     ##       ######            ##   #  ##      ##   #  ##   #   ##     ##   #  ##       ######  ##       ###  #   ##      ##      
 ##     ##     ####     ## # #            #####   ####    ##   #  ##   #   ##     #####   ####     ## # #  ####     #### #   ##       ####   
 ##     ##     ##       ##   #            ## #    ##      ## # #  ##   #   ##     ## #    ##       ##   #  ##       ## ###   ##         ###  
 ##     ##  #  ##   #   ##   #            ##  #   ##   #  ##  ##  ##   #   ##     ##  #   ##   #   ##   #  ##   #   ##  ##   ##  #   #   ##  
 #      ### #  ### ##   #    #            #   ##  ### ##   ## #    ## #    #      #   ##  ### ##   #    #  ### ##   #    #   ### #   ## ###  
#        ###    #### # #    ###          #     #   #### #   ## ##   ##    #      #     #   #### # #    ###  #### # #     #    ###   # ####                                                                                           
********************************************************************************************************************************************
EOF
                        echo ""
                        echo "input REQUIRED ITEMS names and amounts: "

                        REQUIREDITEMS=$(makeNewRequiredItemList)
                        else
                        REQUIREDITEMS="null"

                fi


                read -p "Would you like to add CLASS REQUIREMENTS? (y/n): " CLASSREQUIREMENTS

                if [[ $CLASSREQUIREMENTS == "y" || $CLASSREQUIREMENTS = "Y" ]]
                then
                clear
cat << "EOF"
  ### #   #         ##      ### #    ### #           # ####     ### #   ##    ##    #   #    # ####     ### #   #   #    ### #   #   #  ######    ### #  
 ##  #   ##        ## #    ##  #    ##  #             ##   #   ##  #   ## #    #   #   ##     ##   #   ##  #   ### ##   ##  #   ##   #    #      ##  #   
##       ##       ##   #   ##       ##                ##   #  ##      ##   #  ##   #   ##     ##   #  ##       ######  ##       ###  #   ##      ##      
##       ##       ######    ####     ####             #####   ####    ##   #  ##   #   ##     #####   ####     ## # #  ####     #### #   ##       ####   
##       ##       ##   #      ###      ###            ## #    ##      ## # #  ##   #   ##     ## #    ##       ##   #  ##       ## ###   ##         ###  
##   #   ##    #  ##   #   #   ##   #   ##            ##  #   ##   #  ##  ##  ##   #   ##     ##  #   ##   #   ##   #  ##   #   ##  ##   ##  #   #   ##  
### ##   ###  #   #    #   ## ###   ## ###            #   ##  ### ##   ## #    ## #    #      #   ##  ### ##   #    #  ### ##   #    #   ### #   ## ###  
 #### # # #####  #    ### # ####   # ####            #     #   #### #   ## ##   ##    #      #     #   #### # #    ###  #### # #     #    ###   # ####   
********************************************************************************************************************************************************
EOF
                
                echo
                    echo "Input Required Classes"
                   CLASSREQUIREMENTS=''
                   CLASSREQUIREMENTS=$(makeNewRequiredClassesList)
                   else
                   CLASSREQUIREMENTS="null"
                fi
                clear

                read -p "Would you like to create an ADDRESS WHITELIST who can claim this ITEM? (y/n) " WHITELIST
            if [[ $WHITELIST == "y" || $WHITELIST == "Y" ]]
            then
            clear
            cat << "EOF"
 ::::::::  :::            :::     ::::::::::: ::::    ::::     :::        :::::::::::  ::::::::  ::::::::::: 
:+:    :+: :+:          :+: :+:       :+:     +:+:+: :+:+:+    :+:            :+:     :+:    :+:     :+:     
+:+        +:+         +:+   +:+      +:+     +:+ +:+:+ +:+    +:+            +:+     +:+            +:+     
+#+        +#+        +#++:++#++:     +#+     +#+  +:+  +#+    +#+            +#+     +#++:++#++     +#+     
+#+        +#+        +#+     +#+     +#+     +#+       +#+    +#+            +#+            +#+     +#+     
#+#    #+# #+#        #+#     #+#     #+#     #+#       #+#    #+#            #+#     #+#    #+#     #+#     
 ########  ########## ###     ### ########### ###       ###    ########## ###########  ########      ###     
 ************************************************************************************************************
EOF

                echo ""
                
                WHITELIST=''
                    WHITELIST=$(makeNewAddressMerkle)
                    else
                    WHITELIST="null"
            fi
            
            JSINPUT="$ITEMNAME;$MAXSUPPLY;$IMAGEURI;$SOULBOUND|$REQUIREDITEMS|$CLASSREQUIREMENTS|$WHITELIST"
            echo -ne "Executing dry run  [..    ]\r"
            SAVE_DATA=$(node scripts/helpers/saveExecutionData.js $1 Items $JSINPUT)
            echo -ne "Executing dry run  [....  ]\r"
            INDEXOFNEWITEM=$(echo "$SAVE_DATA" | grep -oE '[[:digit:]]' | tr -d '\n' )
            echo -ne "Executing dry run  [..... ]\r"
            CALLDATA=$(cast calldata "run(string,string)" $1 $INDEXOFNEWITEM);
            FORGE_OUTPUT=$(forge script scripts/$CONTRACT.s.sol:Execute$CONTRACT -s $CALLDATA --rpc-url $NETWORK)
            echo -ne "Executing dry run  [......]\r"
            echo $"FORGE_OUTPUT"
            fi
    fi
                

                

elif [[ $MENU_SELECTION == 3 ]]
then
    echo "roll character sheet"
    CONTRACT="CharacterSheetsImplementation"
    CREATEDCHARACTERSHEETS=$(node scripts/helpers/readAddress.js $1 CreatedCharacterSheet)
    if [[ $CREATEDCHARACTERSHEETS != "" ]]
        then
        echo ""
            echo "Deployed Character Sheets contract detected at: $CREATEDCHARACTERSHEETS"
            echo "-------------------------------------------------------------------------"
            read -p "Would you like to roll a character sheet at this address? (y/n) " CONFIRMATION
            if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
                then 
                clear
cat << "EOF"
# ####     ##      #        #                 ### #   #    #    ##    # ####      ##      ### # ######    ### # # ####              ### #    #    #   ### #   ### # ######  
 ##   #   ## #    ##       ##                ##  #   ##   #    ## #    ##   #    ## #    ##  #    #      ##  #   ##   #            ##  #    ##   #   ##  #   ##  #    #     
 ##   #  ##   #   ##       ##               ##       ##   #   ##   #   ##   #   ##   #  ##       ##     ##       ##   #            ##       ##   #  ##      ##       ##     
 #####   ##   #   ##       ##               ##       ######   ######   #####    ######  ##       ##     ####     #####              ####    ######  ####    ####     ##     
 ## #    ##   #   ##       ##               ##       ##   #   ##   #   ## #     ##   #  ##       ##     ##       ## #                 ###   ##   #  ##      ##       ##     
 ##  #   ##   #   ##    #  ##    #          ##   #   ##   #   ##   #   ##  #    ##   #  ##   #   ##  #  ##   #   ##  #             #   ##   ##   #  ##   #  ##   #   ##  #  
 #   ##   ## #    ###  #   ###  #           ### ##   #    #   #    #   #   ##   #    #  ### ##   ### #  ### ##   #   ##            ## ###   #    #  ### ##  ### ##   ### #  
#     #    ##    # #####  # #####            #### # #    ### #    ### #     #  #    ###  #### #   ###    #### # #     #           # ####   #    ###  #### #  #### #   ###   
***************************************************************************************************************************************************************************
EOF
                    echo ""
                    read -p "Please input the address you would like to mint a character sheet to: " MEMBERADDRESS
                    echo ""
                    read -p "Please input the NAME of your Character: " CHARACTERNAME
                    echo ""
                    read -p "Please input the URI of your characters profile image (leave blank to use default): " CHARURI

                    JSINPUT="$MEMBERADDRESS;$CHARACTERNAME;$CHARURI"
                    
                    SAVE_DATA=$(node scripts/helpers/saveExecutionData.js $1 Characters $JSINPUT)

                    INDEXOF=$(echo "$SAVE_DATA" | grep -oE '[[:digit:]]' | tr -d '\n' )
                    echo -ne "Executing dry run  [..    ]\r"
                    CALLDATA=$(cast calldata "run(string,string)" $1 $INDEXOF);
                    echo -ne "Executing dry run  [...   ]\r"

                    FORGE_OUTPUT=$(forge script scripts/$CONTRACT.s.sol:Execute$CONTRACT -s $CALLDATA --rpc-url $NETWORK)
                     echo -ne "Executing dry run  [......]\r"
                    echo "$FORGE_OUTPUT"
                   


            else
                echo "ERROR!"
                exit 1
            fi
        else
        echo "No deployed contracts detected"
        exit 1
    fi 

else
echo "exit"
exit 1
fi

read -p "Please verify the data and execute the transaction? (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Executing..."

        FORGE_OUTPUT=$(PRIVATE_KEY=$PRIVATE_KEY forge script scripts/$CONTRACT.s.sol:Execute$CONTRACT -s $CALLDATA --rpc-url $NETWORK --broadcast)
        echo "$FORGE_OUTPUT"
fi
    if [[ $CONTRACT == "CharacterSheetsImplementation" ]]
    then
    node node scripts/helpers/getERC6551Address.js $NETWORK Characters $INDEXOF
    fi

fi

echo "END SCRIPT"

exit 0
