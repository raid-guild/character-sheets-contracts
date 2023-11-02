-include .env

.PHONY: all test clean deploy-anvil

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install --no-commit foundry-rs/forge-std openzeppelin/openzeppelin-contracts https://github.com/Hats-Protocol/hats-protocol.git https://github.com/Hats-Protocol/hats-module https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable.git https://github.com/dmfxyz/murky.git

# Update Dependencies
update:; forge update

compile:; forge compile

build:; forge build --sizes

test :; forge test

snapshot :; forge snapshot

slither :; slither --config-file slither.config.json src/.

format :; forge fmt

# solhint should be installed globally
lint :; solhint "src/**/*.sol"

anvil :; anvil -m 'test test test test test test test test test test test junk'

# deploy
deploy :; 
	@if [ ${force} = "true" ]; then \
    ./scripts/deploy.sh ${network} ${contract} --force; \
	else\
    ./scripts/deploy.sh ${network} ${contract}; \
	fi

# verify
verify :; ./scripts/verify.sh ${network} ${contract}

CONTRACTS = \
CharacterAccount \
CharacterSheetsImplementation \
ExperienceImplementation \
ItemsImplementation \
ItemsManagerImplementation \
ClassesImplementation \
MolochV2EligibilityAdaptor \
MolochV3EligibilityAdaptor \
ClassLevelAdaptor \
HatsAdaptor \
AdminHatEligibilityModule \
GameMasterHatEligibilityModule \
PlayerHatEligibilityModule \
CharacterHatEligibilityModule \
ClonesAddressStorageImplementation \
ImplementationAddressStorage \
CharacterSheetsFactory

deploy-contracts :; 
	@for contract in ${CONTRACTS}; do \
		make deploy network=${network} force=${force} contract=$$contract; \
	done

verify-contracts :; 
	@for contract in ${CONTRACTS}; do \
		make verify network=${network} contract=$$contract; \
	done

# execute commands
create-sheets :; scripts/createSheets.sh ${network}  
execute :; scripts/execute.sh ${network}
