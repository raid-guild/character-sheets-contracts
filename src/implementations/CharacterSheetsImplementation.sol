// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {ERC721URIStorage} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Counters} from "openzeppelin-contracts/contracts/utils/Counters.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";

import {IERC6551Registry} from "../interfaces/IERC6551Registry.sol";
import {IMolochDAO} from "../interfaces/IMolochDAO.sol";
import {ItemsImplementation} from "./ItemsImplementation.sol";
import {ClassesImplementation} from "./ClassesImplementation.sol";
import {ExperienceImplementation} from "./ExperienceImplementation.sol";
import {CharacterSheet} from "../lib/Structs.sol";

import {Errors} from "../lib/Errors.sol";
// import "forge-std/console2.sol";

contract CharacterSheetsImplementation is Initializable, ERC721, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    /// @dev the admin of the contract
    bytes32 public constant DUNGEON_MASTER = keccak256("DUNGEON_MASTER");
    /// @dev the EOA of the dao member who owns a sheet
    bytes32 public constant PLAYER = keccak256("PLAYER");
    /// @dev the tokenbound account of the sheet nft
    bytes32 public constant CHARACTER = keccak256("CHARACTER");

    ItemsImplementation public items;
    ClassesImplementation public classes;
    ExperienceImplementation public experience;

    IMolochDAO public dao;

    string public baseTokenURI;
    string public metadataURI;

    IERC6551Registry private _erc6551Registry;
    address public erc6551AccountImplementation;

    // tokenId => characterSheet
    mapping(uint256 => CharacterSheet) public sheets;
    // member address => characterSheet token Id.
    mapping(address => uint256) public memberAddressToTokenId;

    mapping(address => bool) public jailed;

    uint256 public totalSheets;

    event NewCharacterSheetRolled(address member, address erc6551, uint256 tokenId);
    event MetadataURIUpdated(string oldURI, string newURI);
    event BaseURIUpdated(string oldURI, string newURI);
    event CharacterRemoved(uint256 tokenId);
    event ItemsUpdated(address exp);
    event ClassEquipped(uint256 characterId, uint256 classId);
    event ClassUnequipped(uint256 characterId, uint256 classId);
    event ItemEquipped(uint256 characterId, uint256 itemTokenId);
    event ItemUnequipped(uint256 characterId, uint256 itemTokenId);
    event CharacterUpdated(uint256 tokenId, string newName, string newCid);
    event PlayerJailed(address playerAddress, bool thrownInJail);
    event CharacterRestored(uint256 tokenId, address tokenBoundAccount, address player);

    modifier onlyExpContract() {
        require(msg.sender == address(items), "not the items contract");
        _;
    }

    //solhint-disable-next-line
    constructor() ERC721("CharacterSheet", "CHAS") {
        _disableInitializers();
    }

    /**
     *
     * @param _encodedParameters encoded parameters must include:
     * - address daoAddress: the address of the dao who's member list will be allowed to become players and who
     *      will be able to interact with this contract
     * - address[] dungeonMasters: an array addresses of the person/persons who are authorized to issue player
     *      cards, classes, and items.
     * - address owner: the account that will have the DEFAULT_ADMIN role
     * - address CharacterAccountImplementation: the erc 4337 implementation of the Character account.
     * - address erc6551Registry:  the address of the deployed ERC6551 registry on whichever chain these
     *      contracts are on
     * - string metadataURI: the metadata for the character sheets implementation
     * - string baseURI: the default uri of the player card images, arbitrary a different uri can be set
     *      when the character sheet is minted.
     * - address itemsImplementation: this is the address of the ERC1155 items contract associated
     *      with this contract.  this is assigned at contract creation.
     */

    function initialize(bytes calldata _encodedParameters) external initializer {
        _grantRole(DUNGEON_MASTER, msg.sender);

        address daoAddress;
        address[] memory dungeonMasters;
        address owner;
        address classesImplementation;
        address itemsImplementation;
        address erc6551Registry;

        (
            daoAddress,
            dungeonMasters,
            owner,
            classesImplementation,
            itemsImplementation,
            erc6551Registry,
            erc6551AccountImplementation,
            metadataURI,
            baseTokenURI
        ) = abi.decode(
            _encodedParameters, (address, address[], address, address, address, address, address, string, string)
        );

        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        for (uint256 i = 0; i < dungeonMasters.length; i++) {
            _grantRole(DUNGEON_MASTER, dungeonMasters[i]);
        }

        items = ItemsImplementation(itemsImplementation);
        classes = ClassesImplementation(classesImplementation);
        dao = IMolochDAO(daoAddress);
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

    function rollCharacterSheet(address _to, bytes calldata _data) external returns (uint256) {
        if (erc6551AccountImplementation == address(0) || address(_erc6551Registry) == address(0)) {
            revert Errors.VariableNotSet();
        }

        if (dao.members(_to).shares == 0) {
            revert Errors.DaoError();
        }

        if (_to != msg.sender) {
            revert Errors.PlayerOnly();
        }

        if (jailed[msg.sender]) {
            revert Errors.Jailed();
        }

        string memory _newName;
        string memory _tokenURI;
        (_newName, _tokenURI) = abi.decode(_data, (string, string));

        uint256 tokenId = _tokenIdCounter.current();

        if (memberAddressToTokenId[_to] != 0) {
            revert Errors.CharacterError();
        }

        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);

        if (bytes(_tokenURI).length > 0) {
            _setTokenURI(tokenId, _tokenURI);
        } else {
            _setTokenURI(tokenId, baseTokenURI);
        }

        //calculate ERC6551 account address
        address tba = _erc6551Registry.createAccount(
            erc6551AccountImplementation, block.chainid, address(this), tokenId, uint256(uint160(_to)), ""
        );

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
        emit NewCharacterSheetRolled(_to, tba, tokenId);

        return tokenId;
    }

    /**
     * this adds a class to the classes array of the characterSheet struct in storage
     * @param characterId the token id of the player to receive a class
     * @param classId the class ID of the class to be added
     */

    function equipClassToCharacter(uint256 characterId, uint256 classId) external onlyRole(CHARACTER) {
        if (classes.balanceOf(msg.sender, classId) < 1) {
            revert Errors.InsufficientBalance();
        }
        sheets[characterId].classes.push(classId);
        emit ClassEquipped(characterId, classId);
    }

    /**
     * removes a class from a character Sheet
     * @param characterId the id of the character sheet to be modified
     * @param classId the class Id to be removed
     */

    function unequipClassFromCharacter(uint256 characterId, uint256 classId)
        external
        onlyRole(CHARACTER)
        returns (bool success)
    {
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

                emit ClassUnequipped(characterId, classId);
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

    function unequipItemFromCharacter(uint256 characterId, uint256 tokenId)
        external
        onlyRole(CHARACTER)
        returns (bool success)
    {
        uint256[] memory arr = sheets[characterId].inventory;
        if (items.balanceOf(sheets[characterId].ERC6551TokenAddress, tokenId) != 0) {
            revert Errors.InventoryError();
        }
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

                emit ItemUnequipped(characterId, tokenId);
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

    function equipItemToCharacter(uint256 characterId, uint256 itemId) external onlyRole(CHARACTER) {
        if (items.balanceOf(msg.sender, itemId) < 1) {
            revert Errors.InsufficientBalance();
        }
        sheets[characterId].inventory.push(itemId);
        emit ItemEquipped(characterId, itemId);
    }

    /**
     * this will burn the nft of the player.  only a player can burn their own token.
     * @param _characterId the token id to be burned
     */

    function renounceSheet(uint256 _characterId) public returns (bool success) {
        if (balanceOf(msg.sender) == 0) {
            revert Errors.CharacterError();
        }
        address tokenOwner = ownerOf(_characterId);
        if (msg.sender != tokenOwner) {
            revert Errors.OwnershipError();
        }

        //#TODO consider transferring the token in question to this contract instead of burning in order to manage the assets held by the token
        _burn(_characterId);
        //clear memberAddress mapping
        memberAddressToTokenId[msg.sender] = 0;
        emit CharacterRemoved(_characterId);
        success = true;
    }

    /**
     * restores a previously renounced sheet if called by the wrong player and incorrect address will be created that does not control any assets
     * @param tokenId the token Id of the renounced sheet
     */

    function restoreSheet(uint256 tokenId) public onlyRole(PLAYER) {
        if (memberAddressToTokenId[msg.sender] != 0) {
            revert Errors.PlayerError();
        }
        address restoredAccount = _erc6551Registry.createAccount(
            erc6551AccountImplementation, block.chainid, address(this), tokenId, uint256(uint160(msg.sender)), ""
        );
        memberAddressToTokenId[msg.sender] = tokenId;
        emit CharacterRestored(tokenId, restoredAccount, msg.sender);
    }

    /**
     * allows a player to update their name in the contract
     * @param newName the new player name
     */
    function updateCharacterMetadata(string calldata newName, string calldata newCid) public onlyRole(PLAYER) {
        uint256 tokenId = memberAddressToTokenId[msg.sender];

        sheets[tokenId].name = newName;

        _setTokenURI(tokenId, newCid);

        emit CharacterUpdated(tokenId, newName, newCid);
    }

    function jailPlayer(address playerAddress, bool throwInJail) public onlyRole(DUNGEON_MASTER) {
        jailed[playerAddress] = throwInJail;
        emit PlayerJailed(playerAddress, throwInJail);
    }

    function updateExpContract(address expContract) public onlyRole(DUNGEON_MASTER) {
        items = ItemsImplementation(expContract);
        emit ItemsUpdated(expContract);
    }

    function setBaseUri(string memory _uri) public onlyRole(DUNGEON_MASTER) {
        string memory oldBaseURI = baseTokenURI;
        baseTokenURI = _uri;
        emit BaseURIUpdated(oldBaseURI, _uri);
    }

    function setMetadataUri(string memory _uri) public onlyRole(DUNGEON_MASTER) {
        string memory oldMetadataURI = metadataURI;
        metadataURI = _uri;
        emit MetadataURIUpdated(oldMetadataURI, _uri);
    }

    /**
     * Burns a players characterSheet.  can only be done if there is a passing guild kick proposal
     * @param characterId the characterId of the player to be removed.
     */

    function removeSheet(uint256 characterId) public onlyRole(DUNGEON_MASTER) {
        if (dao.members(getCharacterSheetByCharacterId(characterId).memberAddress).jailed == 0) {
            revert Errors.DaoError();
        }

        delete sheets[characterId];
        _burn(characterId);

        emit CharacterRemoved(characterId);
    }

    /// @dev Sets the address of the ERC6551 registry
    function setERC6551Registry(address registry) public onlyRole(DUNGEON_MASTER) {
        _erc6551Registry = IERC6551Registry(registry);
    }

    /// @dev Sets the address of the ERC6551 account implementation
    function setERC6551Implementation(address implementation) public onlyRole(DUNGEON_MASTER) {
        erc6551AccountImplementation = implementation;
    }

    function getCharacterSheetByCharacterId(uint256 tokenId) public view returns (CharacterSheet memory) {
        if (sheets[tokenId].memberAddress == address(0)) {
            revert Errors.CharacterError();
        }
        return sheets[tokenId];
    }

    function getCharacterIdByNftAddress(address _nftAddress) public view returns (uint256) {
        for (uint256 i = 1; i <= totalSheets; i++) {
            if (sheets[i].ERC6551TokenAddress == _nftAddress) {
                return i;
            }
        }
        revert Errors.CharacterError();
    }

    function isClassEquipped(uint256 characterId, uint256 classId) public view returns (bool) {
        CharacterSheet memory sheet = sheets[characterId];
        if (sheet.memberAddress == address(0)) {
            revert Errors.PlayerError();
        }
        if (sheet.classes.length == 0) {
            return false;
        }
        uint256 tokenId = classes.getClassById(classId).tokenId;
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
        if (sheet.memberAddress == address(0)) {
            revert Errors.PlayerError();
        }
        if (sheet.inventory.length == 0) {
            return false;
        }
        uint256 tokenId = items.getItemById(itemId).tokenId;
        require(tokenId != 0, "item does not exist");
        for (uint256 i; i < sheet.inventory.length; i++) {
            if (sheet.inventory[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    // The following functions are overrides required by Solidity.
    // solhint-disable
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
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

    function approve(address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        return super.approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override(ERC721, IERC721) {
        return super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId)
        public
        virtual
        override(ERC721, IERC721)
        onlyRole(DUNGEON_MASTER)
    {
        return super.transferFrom(from, to, tokenId);
    }

    /**
     * revert(Errors."This token cannot be transfered");
     * revert(Errors."This token cannot be transfered");
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        virtual
        override(ERC721, IERC721)
        onlyRole(DUNGEON_MASTER)
    {
        return super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        virtual
        override(ERC721, IERC721)
        onlyRole(DUNGEON_MASTER)
    {
        return super.safeTransferFrom(from, to, tokenId, data);
    }
}
