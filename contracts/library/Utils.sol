// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

library Utils {
    function getRandomNumber(
        uint256 from,
        uint256 to
    ) internal view returns (uint256) {
        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao))
        );
        uint256 seed2 = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))
        );

        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, seed2)
            )
        );

        uint256 result = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    randomNumber
                )
            )
        );

        return ((result % (to - from + 1)) + from);
    }
}
