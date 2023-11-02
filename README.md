# Character Sheets

#### Author: MrDeadCe11

This is a combination of an ERC721 base contract the Character sheets, and an ERC1155 Experience and items. These allow you to mint a erc721 token that will also deploy an ERC6551 token bound account for that token. This acts as a base profile image that can be assigned any erc1155 token on top of that. the items and experience can be give out by the game master which is assigned upon the creation of the contracts.

You will need a copy of [Foundry](https://github.com/foundry-rs/foundry) installed before proceeding. See the [installation guide](https://github.com/foundry-rs/foundry#installation) for details.

### Setup

```sh
git clone https://github.com/MrDeadCe11/character-sheets
cd character-sheets
forge install
```

### Run Tests

```sh
forge test
```

### Update Gas Snapshots

```sh
forge snapshot
```

### Deployment

```sh
make deploy-contracts network=<sepolia/gnosis>
```

### Verify Deployed Contracts

```sh
make verify-contracts network=<sepolia/gnosis>
```

### Create new characterSheets and sub contracts

To use the character Sheets factory you will need the following addresses available to input into the script

- A list of address that you would like to give administrator privileges to.
- the address of the Moloch Dao who's members will be eligible to use the protocol
- the base image uri for the character sheets NFT contract
- the base METADATA uri for the character sheets nft contract
- the base image URI for the Experience and Items ERC1155 contract
- the base image URI for the Classes contract

The bash script will ask for this info during the creation of the contracts you can either paste them directly into the CLI or add them to the addresses.json file before running the script.

```sh
make create-sheets network=<sepolia/gnosis>
```

### Basic contract interactions

once new contracts are deployed you can...

- Make a new Class
- Make a new Item
- Roll a character sheet

```sh
make execute network=<sepolia/gnosis>
```
