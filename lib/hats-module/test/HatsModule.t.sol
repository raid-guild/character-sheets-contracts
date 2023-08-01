// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { Test, console2 } from "forge-std/Test.sol";
import { HatsModule, IHats, Deploy, HatsModuleFactoryTest } from "../test/HatsModuleFactory.t.sol";
import { HatsModuleFactory, deployModuleInstance } from "src/utils/DeployFunctions.sol";

contract HatsModuleHarness is HatsModule {
  event HatsModuleHarness_SetUp(bytes initData);

  constructor(string memory version) HatsModule(version) { }

  function getImmutableBytes(uint256 length) public pure returns (bytes memory) {
    return _getArgBytes(72, length);
  }

  function setUp(bytes calldata _initData) public override initializer {
    emit HatsModuleHarness_SetUp(_initData);
  }
}

contract HatsModuleTest is HatsModuleFactoryTest {
  event HatsModuleHarness_SetUp(bytes initData);

  HatsModuleHarness public impl;
  HatsModuleHarness public inst;
  uint256 public largeBytesLength = largeBytes.length;

  function setUp() public virtual override {
    super.setUp();
    // deploy a new HatsModuleHarness as an implementation contract
    impl = new HatsModuleHarness(MODULE_VERSION);
  }
}

contract DeployImplementation is HatsModuleTest {
  function test_version() public {
    assertEq(impl.version_(), MODULE_VERSION, "incorrect module version");
  }

  function test_setUp_cannotBeCalled() public {
    // expect revert if setUp is called
    vm.expectRevert();
    impl.setUp(abi.encode("setUp attempt"));
  }
}

contract DeployInstance is HatsModuleTest {
  function setUp() public override {
    super.setUp();

    // set up parameters for a new instance
    hatId = hat1_1;
    otherArgs = largeBytes;
    initData = abi.encode("this is init data");
  }

  function test_deployEvent() public {
    // expect event emitted with the initData
    vm.expectEmit(true, true, true, true);
    emit HatsModuleFactory_ModuleDeployed(
      address(impl), factory.getHatsModuleAddress(address(impl), hatId, otherArgs), hatId, otherArgs, initData
    );
    // deploy an instance of HatsModuleHarness via the factory
    // inst = HatsModuleHarness(factory.createHatsModule(address(impl), hatId, otherArgs, initData));
    inst = HatsModuleHarness(deployModuleInstance(factory, address(impl), hatId, otherArgs, initData));
  }

  function test_immutables() public {
    // deploy an instance of HatsModuleHarness via the factory
    inst = HatsModuleHarness(deployModuleInstance(factory, address(impl), hatId, otherArgs, initData));

    assertEq(address(inst.IMPLEMENTATION()), address(impl), "incorrect implementation address");
    assertEq(address(inst.HATS()), address(hats), "incorrect hats address");
    assertEq(inst.hatId(), hatId, "incorrect hatId");
    assertEq(inst.getImmutableBytes(largeBytesLength), largeBytes, "incorrect otherArgs");
  }

  function test_version() public {
    // deploy an instance of HatsModuleHarness via the factory
    inst = HatsModuleHarness(deployModuleInstance(factory, address(impl), hatId, otherArgs, initData));

    assertEq(inst.version(), MODULE_VERSION, "incorrect module version");
  }

  function test_setUp_cannotBeCalledTwice() public {
    // deploy an instance of HatsModuleHarness via the factory
    inst = HatsModuleHarness(deployModuleInstance(factory, address(impl), hatId, otherArgs, initData));

    // expect revert if setUp is called again
    vm.expectRevert();
    inst.setUp(abi.encode("another setUp attempt"));
  }

  function test_initData() public {
    // expect event emitted with the initData
    vm.expectEmit(true, true, true, true);
    emit HatsModuleHarness_SetUp(initData);
    // deploy an instance of HatsModuleHarness via the factory
    inst = HatsModuleHarness(deployModuleInstance(factory, address(impl), hatId, otherArgs, initData));
  }
}
