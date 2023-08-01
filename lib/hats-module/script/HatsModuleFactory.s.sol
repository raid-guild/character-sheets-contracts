// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { Script, console2 } from "forge-std/Script.sol";
import { HatsModule, HatsModuleFactory, IHats, deployModuleFactory } from "src/utils/DeployFunctions.sol";

contract Deploy is Script {
  HatsModuleFactory public factory;
  IHats public constant hats = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth
  bytes32 public SALT = bytes32(abi.encode(0x4a75)); // ~ H(4) A(a) T(7) S(5)

  // default values
  string public version = "0.3.0"; // increment with each deploy
  bool private verbose = true;

  /// @notice Override default values, if desired
  function prepare(string memory _version, bool _verbose) public {
    version = _version;
    verbose = _verbose;
  }

  function run() public {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(privKey);
    vm.startBroadcast(deployer);

    factory = deployModuleFactory(hats, SALT, version);

    vm.stopBroadcast();

    if (verbose) {
      console2.log("HatsModuleFactory:", address(factory));
    }
  }
}

// forge script script/Deploy.s.sol -f ethereum --broadcast --verify
