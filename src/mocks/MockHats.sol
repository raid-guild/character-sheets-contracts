// SPDX-License-Identifier: AGPL-3.0
// Copyright (C) 2023 Haberdasher Labs
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.8.13;

import "hats-protocol/src/Hats.sol";

contract MockHats {
    struct Hat {
        // 1st storage slot
        address eligibility; // ─┐ 20
        uint32 maxSupply; //     │ 4
        uint32 supply; //        │ 4
        uint16 lastHatId; //    ─┘ 2
        // 2nd slot
        address toggle; //      ─┐ 20
        uint96 config; //       ─┘ 12
        // 3rd+ slot (optional)
        string details;
        string imageURI;
    }

    uint256 hatIds = 1;
    mapping(address => mapping(uint256 => uint256)) _balanceOf;

    /*//////////////////////////////////////////////////////////////
                              HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the contract, typically including the version
    string public name;

    /// @notice The first 4 bytes of the id of the last tophat created.
    uint32 public lastTopHatId; // first tophat id starts at 1

    /// @notice The fallback image URI for hat tokens with no `imageURI` specified in their branch
    string public baseImageURI;

    /// @dev Internal mapping of hats to hat ids. See HatsIdUtilities.sol for more info on how hat ids work
    mapping(uint256 => Hat) internal _hats; // key: hatId => value: Hat struct

    /// @notice Mapping of wearers in bad standing for certain hats
    /// @dev Used by external contracts to trigger penalties for wearers in bad standing
    ///      hatId => wearer => !standing
    mapping(uint256 => mapping(address => bool)) public badStandings;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice All arguments are immutable; they can only be set once during construction
    /// @param _name The name of this contract, typically including the version
    /// @param _baseImageURI The fallback image URI
    constructor(string memory _name, string memory _baseImageURI) {
        name = _name;
        baseImageURI = _baseImageURI;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates and mints a Hat that is its own admin, i.e. a "topHat"
    /// @dev A topHat has no eligibility and no toggle
    /// @param _target The address to which the newly created topHat is minted
    /// @param _details A description of the Hat [optional]. Should not be larger than 7000 bytes
    ///                 (enforced in changeHatDetails)
    /// @param _imageURI The image uri for this top hat and the fallback for its
    ///                  downstream hats [optional]. Should not be large than 7000 bytes
    ///                  (enforced in changeHatImageURI)
    /// @return topHatId The id of the newly created topHat
    function mintTopHat(address _target, string calldata _details, string calldata _imageURI)
        public
        returns (uint256 topHatId)
    {
        // create hat

        topHatId = uint256(++lastTopHatId) << 224;

        _createHat(
            topHatId,
            _details, // details
            1, // maxSupply = 1
            address(0), // there is no eligibility
            address(0), // it has no toggle
            false, // its immutable
            _imageURI
        );

        _mintHat(_target, topHatId);
    }

    /// @notice Creates a new hat. The msg.sender must wear the `_admin` hat.
    /// @dev Initializes a new Hat struct, but does not mint any tokens.
    /// @param _details A description of the Hat. Should not be larger than 7000 bytes (enforced in changeHatDetails)
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _admin The id of the Hat that will control who wears the newly created hat
    /// @param _eligibility The address that can report on the Hat wearer's status
    /// @param _toggle The address that can deactivate the Hat
    /// @param _mutable Whether the hat's properties are changeable after creation
    /// @param _imageURI The image uri for this hat and the fallback for its
    ///                  downstream hats [optional]. Should not be larger than 7000 bytes (enforced in changeHatImageURI)
    /// @return newHatId The id of the newly created Hat
    function createHat(
        uint256 _admin,
        string calldata _details,
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string calldata _imageURI
    ) public returns (uint256 newHatId) {
        if (uint16(_admin) > 0) {
            revert MaxLevelsReached();
        }
        // construct the next hat id
        newHatId = hatIds;
        // to create a hat, you must be wearing one of its admin hats
        // create the new hat
        _createHat(newHatId, _details, _maxSupply, _eligibility, _toggle, _mutable, _imageURI);
        // increment _admin.lastHatId
        // use the overflow check to constrain to correct number of hats per level
        ++_hats[_admin].lastHatId;
        hatIds++;
    }

    function _createHat(
        uint256 _id,
        string calldata _details,
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string calldata _imageURI
    ) internal {
        /* 
          We write directly to storage instead of first building the Hat struct in memory.
          This allows us to cheaply use the existing lastHatId value in case it was incremented by creating a hat while skipping admin levels.
          (Resetting it to 0 would be bad since this hat's child hat(s) would overwrite the previously created hat(s) at that level.)
        */
        Hat storage hat = _hats[_id];
        hat.details = _details;
        hat.maxSupply = _maxSupply;
        hat.eligibility = _eligibility;
        hat.toggle = _toggle;
        hat.imageURI = _imageURI;
        // config is a concatenation of the status and mutability properties
        hat.config = _mutable ? uint96(3 << 94) : uint96(1 << 95);

        // emit HatCreated(_id, _details, _maxSupply, _eligibility, _toggle, _mutable, _imageURI);
    }

    /// @notice Internal call to mint a Hat token to a wearer
    /// @dev Unsafe if called when `_wearer` has a non-zero balance of `_hatId`
    /// @param _wearer The wearer of the Hat and the recipient of the newly minted token
    /// @param _hatId The id of the Hat to mint
    function _mintHat(address _wearer, uint256 _hatId) internal {
        unchecked {
            // should not overflow since `mintHat` enforces max balance of 1
            _balanceOf[_wearer][_hatId] = 1;

            // increment Hat supply counter
            // should not overflow given AllHatsWorn check in `mintHat`
            ++_hats[_hatId].supply;
        }

        // emit TransferSingle(msg.sender, address(0), _wearer, _hatId, 1);
    }
}
