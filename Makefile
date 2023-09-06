-include .env

.PHONY: all test clean deploy-anvil

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std && forge install openzeppelin/openzeppelin-contracts && git submodule add https://github.com/Hats-Protocol/hats-protocol.git lib/hats && git submodule add https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable.git lib/openzeppelin-contracts-upgradeable && git submodule add https://github.com/dmfxyz/murky.git lib/murky && cd lib/hats forge install && cd ../.. && forge remappings > remappings.txt

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

snapshot :; forge snapshot

slither :; slither --config-file slither.config.json src/.

format :; prettier --write src/**/*.sol && prettier --write src/*.sol

# solhint should be installed globally
lint :; solhint src/**/*.sol && solhint src/*.sol

anvil :; anvil -m 'test test test test test test test test test test test junk' --fork-url ${SEPOLIA_RPC_URL}

# deploy commands
deploy-anvil :; ./scripts/deploy.sh anvil ${contract}
deploy-sepolia :; ./scripts/deploy.sh sepolia ${contract} --verify
deploy-goerli :; ./scripts/deploy.sh goerli ${contract} --verify
deploy-gnosis :; ./scripts/deploy.sh gnosis ${contract} --verify

# verify commands
verify-sepolia :; ./scripts/verify.sh sepolia ${contract}
verify-goerli :; ./scripts/verify.sh goerli ${contract}
verify-gnosis :; ./scripts/verify.sh gnosis ${contract}

deploy-contracts :; make deploy-${network} contract=CharacterAccount && \
	make deploy-${network} contract=CharacterSheetsImplementation && \
	make deploy-${network} contract=ExperienceAndItemsImplementation && \
	make deploy-${network} contract=ClassesImplementation && \
	make deploy-${network} contract=CharacterSheetsFactory;

deploy-all :; make deploy-contracts ${network}&& \
	make deploy-${network} contract=CharacterAccount && \
	make deploy-${network} contract=CharacterSheetsImplementation && \
	make deploy-${network} contract=ExperienceAndItemsImplementation && \
	make deploy-${network} contract=ClassesImplementation && \
	make deploy-${network} contract=CharacterSheetsFactory;

verify-contracts :; make verify-${network} contract=CharacterAccount && \
	make verify-${network} contract=CharacterSheetsImplementation && \
	make verify-${network} contract=ExperienceAndItemsImplementation && \
	make verify-${network} contract=ClassesImplementation && \
	make verify-${network} contract=CharacterSheetsFactory;

# execute commands
create-sheets :; scripts/createSheets.sh ${network}  
execute :; scripts/execute.sh ${network}
