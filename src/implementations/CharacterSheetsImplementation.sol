// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IERC6551Registry.sol";
import "../interfaces/IMolochDAO.sol";
import "./ExperienceAndItemsImplementation.sol";
import "forge-std/console2.sol";
import "../lib/Structs.sol";

contract CharacterSheetsImplementation is Initializable, ERC721, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    /// @dev the admin of the contract
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    /// @dev the EOA of the dao member who owns a character sheet
    bytes32 public constant PLAYER = keccak256("PLAYER");
    /// @dev the tokenbound account of the character sheet nft
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    ExperienceAndItemsImplementation public experience;

    IMolochDAO public dao;

    string public baseTokenURI;

    IERC6551Registry _erc6551Registry;
    address erc6551AccountImplementation;

    event NewPlayer(uint256 tokenId, address memberAddress);
    event PlayerRemoved(uint256 tokenId);
    event ExperienceUpdated(address exp);
    event ClassEquipped(uint256 characterId, uint256 classId);
    event ItemAdded(uint256 characterId, uint256 itemTokenId);
    event PlayerNameUpdated(string oldName, string newName);

    // tokenId => characterSheet
    mapping(uint256 => CharacterSheet) public sheets;
    // member address => characterSheet token Id.
    mapping(address => uint256) public memberAddressToTokenId;

    uint256 totalSheets;

    constructor() ERC721("CharacterSheet", "CHAS") {
        _disableInitializers();
    }

    modifier onlyExpContract() {
        require(msg.sender == address(experience), "not the experience contract");
        _;
    }
    /**
     *
     * @param _encodedParameters encoded parameters must include:
     * - address daoAddress: the address of the dao who's member list will be allowed to become players and who will be able to interact with this contract
     * - address[] dungeonMasters: an array addresses of the person/persons who are authorized to issue player cards, classes, and items.
     * - address owner: the account that will have the DEFAULT_ADMIN role
     * - address CharacterAccountImplementation: the erc 4337 implementation of the Character account.
     * - address erc6551Registry:  the address of the deployed ERC6551 registry on whichever chain these contracts are on
     * - string baseURI: the default uri of the player card images, arbitrary a different uri can be set when the character sheet is minted.
     * - address experienceImplementation: this is the address of the ERC1155 experience contract associated with this contract.  this is assigned at contract creation.
     */

    function initialize(bytes calldata _encodedParameters) public initializer {
        _grantRole(DUNGEON_MASTER, msg.sender);

        address daoAddress;
        address[] memory dungeonMasters;
        address owner;
        address CharacterAccountImplementation;
        address erc6551Registry;
        string memory baseUri;
        address experienceImplementation;

        (
            daoAddress,
            dungeonMasters,
            owner,
            experienceImplementation,
            erc6551Registry,
            CharacterAccountImplementation,
            baseUri
        ) = abi.decode(_encodedParameters, (address, address[], address, address, address, address, string));

        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        for (uint256 i = 0; i < dungeonMasters.length; i++) {
            _grantRole(DUNGEON_MASTER, dungeonMasters[i]);
        }

        setBaseUri(baseUri);
        experience = ExperienceAndItemsImplementation(experienceImplementation);
        dao = IMolochDAO(daoAddress);
        erc6551AccountImplementation = CharacterAccountImplementation;
        _erc6551Registry = IERC6551Registry(erc6551Registry);
        _tokenIdCounter.increment();

        _revokeRole(DUNGEON_MASTER, msg.sender);
    }

    /**
     *
     * @param _to the address of the dao member wallet that will hold the character sheet nft
     * @param _data encoded data that contains the name of the member and the uri of the base image for the nft.
     * if no uri is stored then it will revert to the base uri of the contract
     */

    function rollCharacterSheet(address _to, bytes calldata _data) public onlyRole(DUNGEON_MASTER) returns (uint256) {
        require(
            erc6551AccountImplementation != address(0) && address(_erc6551Registry) != address(0),
            "ERC6551 acount implementation and registry not set"
        );

        require(dao.members(_to).shares > 0, "Player is not a member of the dao");

        string memory _newName;
        string memory _tokenURI;
        (_newName, _tokenURI) = abi.decode(_data, (string, string));

        uint256 tokenId = _tokenIdCounter.current();

        require(memberAddressToTokenId[_to] == 0, "this player is already in the game");

        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);

        if (bytes(_tokenURI).length > 0) {
            _setTokenURI(tokenId, _tokenURI);
        } else {
            _setTokenURI(tokenId, baseTokenURI);
        }

        //calculate ERC6551 account address
        address tba =
            _erc6551Registry.createAccount(erc6551AccountImplementation, block.chainid, address(this), tokenId, 0, "");

        CharacterSheet memory newCharacterSheet;
        newCharacterSheet.name = _newName;
        newCharacterSheet.ERC6551TokenAddress = tba;
        newCharacterSheet.memberAddress = _to;
        newCharacterSheet.tokenId = tokenId;
        //store info in mappings
        sheets[tokenId] = newCharacterSheet;
        memberAddressToTokenId[_to] = tokenId;

        totalSheets++;
        _grantRole(PLAYER, _to);
        _grantRole(CHARACTER, tba);
        emit NewPlayer(tokenId, _to);

        return tokenId;
    }

    /**
     * this adds a class to the classes array of the characterSheet struct in storage
     * @param characterId the token id of the player to receive a class
     * @param classId the class ID of the class to be added
     */

    function equipClassToCharacter(uint256 characterId, uint256 classId) external onlyExpContract {
        sheets[characterId].classes.push(classId);
        emit ClassEquipped(characterId, classId);
    }

    /**
     * removes a class from a character Sheet
     * @param characterId the id of the character sheet to be modified
     * @param classId the class Id to be removed
     */

    function unequipClassFromCharacter(uint256 characterId, uint256 classId) external onlyExpContract returns (bool success) {
        uint256[] memory arr = sheets[characterId].classes;
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == classId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = 0;
                    }
                }
                sheets[characterId].classes = arr;
                sheets[characterId].classes.pop();

                return success = true;
            }
        }
        return success = false;
    }

    /**
     * unequips an itemtype from a character sheet inventory
     * @param characterId the player to have the item type from their inventory
     * @param tokenId the erc1155 token id of the item to be unequipped
     */

    function unequipItemFromCharacter(uint256 characterId, uint256 tokenId) external onlyExpContract returns (bool success) {
        uint256[] memory arr = sheets[characterId].inventory;
        require(experience.balanceOf(sheets[characterId].ERC6551TokenAddress, tokenId) == 0, "empty your inventory first");
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == tokenId) {
                for (uint256 j = i; j < arr.length; j++) {
                    if (j + 1 < arr.length) {
                        arr[j] = arr[j + 1];
                    } else if (j + 1 >= arr.length) {
                        arr[j] = 0;
                    }
                }

                sheets[characterId].inventory = arr;
                sheets[characterId].inventory.pop();

                return success = true;
            }
        }
        return success = false;
    }

    /**
     * adds an item to the items array in the player struct
     * @param characterId the id of the player receiving the item
     * @param itemId the itemId of the item
     */

    function equipItemToCharacter(uint256 characterId, uint256 itemId) external onlyExpContract {
        sheets[characterId].inventory.push(itemId);
        emit ItemAdded(characterId, itemId);
    }

    function getCharacterSheetByCharacterId(uint256 tokenId) public view returns (CharacterSheet memory) {
        require(sheets[tokenId].memberAddress > address(0), "This is not a character.");
        return sheets[tokenId];
    }

    function getCharacterIdByNftAddress(address _nftAddress) public view returns (uint256) {
        for (uint256 i = 1; i <= totalSheets; i++) {
            if (sheets[i].ERC6551TokenAddress == _nftAddress) {
                return i;
            }
        }
        revert("This is not the address of an Character");
    }

    /**
     * Burns a players characterSheet.  can only be done if there is a passing guild kick proposal
     * @param characterId the characterId of the player to be removed.
     */

    function removeSheet(uint256 characterId) public onlyRole(DUNGEON_MASTER) {
        require(
            dao.members(getCharacterSheetByCharacterId(characterId).memberAddress).jailed > 0,
            "There has been no passing guild kick proposal on this player."
        );
        delete sheets[characterId];
        _burn(characterId);

        emit PlayerRemoved(characterId);
    }

    function isClassEquipped(uint256 characterId, uint256 classId) public view returns (bool) {
        CharacterSheet memory sheet = sheets[characterId];
        require(sheet.memberAddress != address(0), "not a player");
        if (sheet.classes.length == 0) {
            return false;
        }
        uint256 tokenId = experience.getClassById(classId).tokenId;
        require(tokenId != 0, "Class does not exist");
        for (uint256 i; i < sheet.classes.length; i++) {
            if (sheet.classes[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    function isItemEquipped(uint256 characterId, uint256 itemId) public view returns (bool) {
        CharacterSheet memory sheet = sheets[characterId];
        require(sheet.memberAddress != address(0), "not a player");
        if (sheet.inventory.length == 0) {
            return false;
        }
        uint256 tokenId = experience.getItemById(itemId).tokenId;
        require(tokenId != 0, "item does not exist");
        for (uint256 i; i < sheet.inventory.length; i++) {
            if (sheet.inventory[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    /**
     * this will burn the nft of the player.  only a player can burn their own token.
     * @param _characterId the token id to be burned
     */

    function renounceSheet(uint256 _characterId) public returns (bool success) {
        require(balanceOf(msg.sender) > 0, "you do not have a characterSheet");
        address tokenOwner = ownerOf(_characterId);
        require(msg.sender == tokenOwner, "You cannot renounce a token you do not own");
        _burn(_characterId);
        emit PlayerRemoved(_characterId);
        success = true;
    }

    /**
     * allows a player to update their name in the contract
     * @param newName the new player name
     */
    function updatePlayerName(string calldata newName) public onlyRole(PLAYER) {
        string memory oldName = sheets[memberAddressToTokenId[msg.sender]].name;
        sheets[memberAddressToTokenId[msg.sender]].name = newName;

        emit PlayerNameUpdated(oldName, newName);
    }

    function setExperienceAndGearContract(address _experience) public onlyRole(DUNGEON_MASTER) {
        experience = ExperienceAndItemsImplementation(_experience);
    }

    function updateExpContract(address expContract) external onlyRole(DUNGEON_MASTER) {
        experience = ExperienceAndItemsImplementation(expContract);
        emit ExperienceUpdated(expContract);
    }

    function setBaseUri(string memory _uri) public onlyRole(DUNGEON_MASTER) {
        baseTokenURI = _uri;
    }
    // The following functions are overrides required by Solidity.

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /// @dev Sets the address of the ERC6551 registry
    function setERC6551Registry(address registry) public onlyRole(DUNGEON_MASTER) {
        _erc6551Registry = IERC6551Registry(registry);
    }

    /// @dev Sets the address of the ERC6551 account implementation
    function setERC6551Implementation(address implementation) public onlyRole(DUNGEON_MASTER) {
        erc6551AccountImplementation = implementation;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // transfer overrides since these tokens should be soulbound or only transferable by the dungeonMaster

    /**
     * @dev See {IERC721-approve}.
     */
    // solhint-disable-next-line unused-var
    function approve(address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        revert("This token cannot be transfered");
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override(ERC721, IERC721) {
        revert("This token cannot be transfered");
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        revert("Cannot transfer characterSheets");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        revert("Cannot transfer characterSheets");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        virtual
        override(ERC721, IERC721)
    {
        revert("Cannot transfer characterSheets");
    }
}
