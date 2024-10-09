// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFTSwap is ReentrancyGuard, AccessControl {
    bytes32 public constant BACKEND_ROLE = keccak256("BACKEND_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

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
    ) external nonReentrant onlyRole(BACKEND_ROLE) {
        require(
            nftContractsGivenByA.length == tokenIdsGivenByA.length &&
                nftContractsGivenByB.length == tokenIdsGivenByB.length,
            "Array length mismatch"
        );

        bool successAGivesToB = _performNFTTransfers(
            nftContractsGivenByA,
            tokenIdsGivenByA,
            userA,
            userB
        );
        bool successBGivesToA = _performNFTTransfers(
            nftContractsGivenByB,
            tokenIdsGivenByB,
            userB,
            userA
        );

        require(successAGivesToB && successBGivesToA, "NFT transfer failed");

        emit NFTSwapCompleted(userA, userB);
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

    function grantBackendRole(
        address backendAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BACKEND_ROLE, backendAddress);
    }
}
