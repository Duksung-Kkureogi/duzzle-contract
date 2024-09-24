// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTSwap is ReentrancyGuard {
    event NFTSwapCompleted(address indexed user1, address indexed user2);
    event NFTSwapFailed(
        address indexed user1,
        address indexed user2,
        string reason
    );

    function executeNFTSwap(
        address[] calldata nftContractsGivenByA,
        uint256[] calldata tokenIdsGivenByA,
        address[] calldata nftContractsGivenByB,
        uint256[] calldata tokenIdsGivenByB,
        address userA,
        address userB
    ) external nonReentrant {
        require(
            nftContractsGivenByA.length == tokenIdsGivenByA.length &&
                nftContractsGivenByB.length == tokenIdsGivenByB.length,
            "Array length mismatch"
        );

        // userA 제공하는 NFT를 userB에게 전송
        bool successAGivesToB = _performNFTTransfers(
            nftContractsGivenByA,
            tokenIdsGivenByA,
            userA,
            userB
        );

        // userB 제공하는 NFT를 userA에게 전송
        bool successBGivesToA = _performNFTTransfers(
            nftContractsGivenByB,
            tokenIdsGivenByB,
            userA,
            userB
        );

        if (successAGivesToB && successBGivesToA) {
            emit NFTSwapCompleted(userA, userB);
        } else {
            emit NFTSwapFailed(userA, userB, "Transfer failed");
            revert("NFT swap failed");
        }
    }

    function _performNFTTransfers(
        address[] calldata nftContracts,
        uint256[] calldata tokenIds,
        address from,
        address to
    ) private returns (bool) {
        for (uint i = 0; i < nftContracts.length; i++) {
            IERC721 nft = IERC721(nftContracts[i]);
            try nft.transferFrom(from, to, tokenIds[i]) {
                if (nft.ownerOf(tokenIds[i]) != to) {
                    return false;
                }
            } catch {
                return false;
            }
        }
        return true;
    }
}
