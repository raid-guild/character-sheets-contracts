-include .env

.PHONY: all test clean deploy-anvil

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std && forge install allo-protocol/contracts

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

snapshot :; forge snapshot

slither :; slither ./src

format :; prettier --write src/**/*.sol && prettier --write src/*.sol

# solhint should be installed globally
lint :; solhint src/**/*.sol && solhint src/*.sol

anvil :; anvil -m 'test test test test test test test test test test test junk' --fork-url ${SEPOLIA_RPC_URL}

# deploy commands
deploy-anvil :; ./scripts/deploy.sh anvil ${contract}
deploy-sepolia :; ./scripts/deploy.sh sepolia ${contract} --verify
deploy-gnosis :; ./scripts/deploy.sh gnosis ${contract} --verify

deploy-contracts :; make deploy-${network} contract=CharacterAccount && \
	make deploy-${network} contract=CharacterSheetsImplementation && \
	make deploy-${network} contract=ExperienceAndItemsImplementation && \
	make deploy-${network} contract=CharacterSheetsFactory;

deploy-all :; make deploy-contracts ${network}&& \
	make deploy-${network} contract=CharacterAccount && \
	make deploy-${network} contract=CharacterSheetsImplementation && \
	make deploy-${network} contract=ExperienceAndItemsImplementation && \
	make deploy-${network} contract=CharacterSheetsFactory;

# execute commands
create-round :; scripts/execute.sh ${network} CharacterSheetsFactory create
