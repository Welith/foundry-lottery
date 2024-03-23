// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract HelperConfigTest is Test {
    HelperConfig private helperConfig;

    function setUp() public {}

    function testConfigGetsSepoliaConfig() public {
        vm.chainId(11155111);
        helperConfig = new HelperConfig();

        assertEq(helperConfig.getEntranceFee(), 0.01 ether);
        assertEq(helperConfig.getInterval(), 30);
        assertEq(
            helperConfig.getVRFCoordinator(),
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        assertEq(
            helperConfig.getGasLane(),
            0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
        );
        assertEq(helperConfig.getSubscriptionId(), 10372);
        assertEq(helperConfig.getCallbackGasLimit(), 500000);
        assertEq(
            helperConfig.getLinkToken(),
            0x779877A7B0D9E8603169DdbD7836e478b4624789
        );
        assertEq(helperConfig.getDeployerKey(), vm.envUint("DEPLOYER_KEY"));
    }
}
