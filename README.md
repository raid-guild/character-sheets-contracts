# Character Sheets

This is a combination of an ERC721 base contract the Character sheets, and an ERC1155 Experience and items. These allow you to mint a erc721 token that will also deploy an ERC6551 token bound account for that token. This acts as a base profile image that can be assigned any erc1155 token on top of that. the items and experience can be give out by the dungeon master which is assigned upon the creation of the contracts.

## Contributing

You will need a copy of [Foundry](https://github.com/foundry-rs/foundry) installed before proceeding. See the [installation guide](https://github.com/foundry-rs/foundry#installation) for details.

### Setup

```sh
git clone https://github.com/MrDeadCe11/character-sheets
cd character-sheets
make install
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

### Verify

```sh
make verify-contracts network=<sepolia/gnosis>
```
