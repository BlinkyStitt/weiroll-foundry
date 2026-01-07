// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {CommandBuilder} from "../CommandBuilder.sol";
import {Test} from "forge-std/Test.sol";

contract CommandBuilderHarness is Test {
    using CommandBuilder for bytes[];

    uint256 constant IDX_VARIABLE_LENGTH = 0x80;
    uint256 constant IDX_VALUE_MASK = 0x7f;
    uint256 constant IDX_END_OF_ARGS = 0xff;
    uint256 constant IDX_USE_STATE = 0xfe;

    function tryDecodeBytes(bytes memory data) external pure returns (bytes[] memory) {
        return abi.decode(data, (bytes[]));
    }

    function basecall() public pure {}

    function testBuildInputsBaseGas(bytes[] memory state, bytes4 selector, bytes32 indices)
        public
        view
        returns (bytes memory out)
    {}

    function testWriteOutputsBaseGas(bytes[] memory state, bytes1 index, bytes memory output)
        public
        pure
        returns (bytes[] memory, bytes memory)
    {
        (index, output); // shh compiler
        return (state, new bytes(32));
    }

    function testBuildInputs(bytes[] memory state, bytes4 selector, bytes32 indices)
        public
        view
        returns (bytes memory)
    {
        // Validate assumptions for each index
        for (uint256 i; i < 32; i++) {
            uint256 idx = uint8(indices[i]);
            if (idx == IDX_END_OF_ARGS) break;

            if (idx == IDX_USE_STATE) continue;

            uint256 stateIndex = idx & IDX_VALUE_MASK;
            vm.assume(stateIndex < state.length);

            if (idx & IDX_VARIABLE_LENGTH != 0) {
                // Dynamic state variables must be a multiple of 32 bytes
                vm.assume(state[stateIndex].length % 32 == 0);
            } else {
                // Static state variables must be exactly 32 bytes
                vm.assume(state[stateIndex].length == 32);
            }
        }

        bytes memory input = state.buildInputs(selector, indices);

        return input;
    }

    function testWriteOutputs(bytes[] memory state, bytes1 index, bytes memory output)
        public
        view
        returns (bytes[] memory, bytes memory)
    {
        uint256 idx = uint8(index);

        if (idx != IDX_END_OF_ARGS) {
            uint256 stateIndex = idx & IDX_VALUE_MASK;

            if (idx == IDX_USE_STATE) {
                // output must be valid abi-encoded bytes[]
                // Try to decode - skip if invalid
                try this.tryDecodeBytes(output) {}
                catch {
                    vm.assume(false);
                }
            } else if (idx & IDX_VARIABLE_LENGTH != 0) {
                // Variable length return: first word must be 0x20 (pointer to data at offset 32)
                vm.assume(output.length >= 64);
                bytes32 firstWord;
                assembly {
                    firstWord := mload(add(output, 0x20))
                }
                vm.assume(firstWord == bytes32(uint256(0x20)));
                vm.assume(stateIndex < state.length);
            } else {
                // Static return: output must be exactly 32 bytes
                vm.assume(output.length == 32);
                vm.assume(stateIndex < state.length);
            }
        }

        state = state.writeOutputs(index, output);

        return (state, output);
    }
}
