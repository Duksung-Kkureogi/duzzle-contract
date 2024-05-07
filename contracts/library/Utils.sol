// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";

library Utils {
    function getRandomNumber(
        uint256 from,
        uint256 to
    ) public view returns (uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    (to + from * 17) - from
                )
            )
        );
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    31 * (to + seed) - from
                )
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
