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

anvil :; anvil -m 'junk junk junk junk junk junk junk junk junk junk junk junk'

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
	make deploy-${network} contract=ExperienceImplementation && \
	make deploy-${network} contract=ItemsImplementation && \
	make deploy-${network} contract=ClassesImplementation && \
	make deploy-${network} contract=CharacterEligibilityAdaptor && \
	make deploy-${network} contract=ClassLevelAdaptor && \
	make deploy-${network} contract=HatsAdaptor && \
	make deploy-${network} contract=AdminHatEligibilityModule && \
	make deploy-${network} contract=DungeonMasterHatEligibilityModule && \
	make deploy-${network} contract=PlayerHatEligibilityModule && \
	make deploy-${network} contract=CharacterHatEligibilityModule && \
	make deploy-${network} contract=CharacterSheetsFactory;

verify-contracts :; make verify-${network} contract=CharacterAccount && \
	make verify-${network} contract=CharacterSheetsImplementation && \
	make verify-${network} contract=ExperienceImplementation && \
	make verify-${network} contract=ItemsImplementation && \
	make verify-${network} contract=ClassesImplementation && \
	make verify-${network} contract=CharacterEligibilityAdaptor && \
	make verify-${network} contract=ClassLevelAdaptor && \
	make verify-${network} contract=HatsAdaptor && \
	make verify-${network} contract=AdminHatEligibilityModule && \
	make verify-${network} contract=DungeonMasterHatEligibilityModule && \
	make verify-${network} contract=PlayerHatEligibilityModule && \
	make verify-${network} contract=CharacterHatEligibilityModule && \
	make verify-${network} contract=CharacterSheetsFactory;

# execute commands
create-sheets :; scripts/createSheets.sh ${network}  
execute :; scripts/execute.sh ${network}
