// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../library/DuzzleLibrary.sol";
import "../library/Utils.sol";

import "../erc-721/MaterialItem.sol";
import "../erc-20/Dal.sol";
import "../erc-721/BlueprintItem.sol";
import "hardhat/console.sol";

using Utils for uint256;

contract PlayDuzzle is AccessControl {
    uint8 public thisSeasonId; // 현재 시즌 id
    uint8[] public seasonIds; // 지금까지의 시즌 id array
    mapping(uint8 => DuzzleLibrary.Season) public seasons; // 시즌별 정보
    Dal public dalToken;
    address public dalTokenAddress;

    BlueprintItem public blueprintItemToken;
    address public blueprintItemTokenAddress;

    event StartSeason(address[] itemAddresses);
    event SetZoneData(
        uint8 zoneId,
        uint8 pieceCountOfZones,
        address[] requiredItemsForMinting,
        uint8[] requiredItemAmount
    );
    event GetRandomItem(address tokenAddress, uint tokenId, address to);

    constructor(uint capOfDalToken, string memory bluePrintBaseUri) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        thisSeasonId = 0;
        dalToken = new Dal(capOfDalToken, address(this));
        dalTokenAddress = address(dalToken);

        blueprintItemToken = new BlueprintItem(bluePrintBaseUri, address(this));
        blueprintItemTokenAddress = address(blueprintItemToken);
    }

    function startSeason(
        address[] calldata existedItemCollections, // 기존 재료아이템 (토큰 주소)
        string[] calldata newItemNames, // 새로운 재료 아이템 이름
        string[] calldata newItemSymbols, // 새로운 재료 아이템 심볼
        uint16[] calldata maxSupplys, //  재료 아이템 발행 제한 개수
        uint24 _totalPieceCount // 총 퍼즐피스 수
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // 두 번째 시즌부터 +1
        if (seasonIds.length > 0) {
            ++thisSeasonId;
        }
        seasonIds.push(thisSeasonId);

        seasons[thisSeasonId].totalPieceCount = _totalPieceCount;
        seasons[thisSeasonId].mintedCount = 0;
        seasons[thisSeasonId].mintedBlueprint = new bool[](_totalPieceCount); // default value: false

        seasons[thisSeasonId].startedAt = block.timestamp;

        uint256 materialItemCount = existedItemCollections.length +
            newItemNames.length;
        address[] memory materialItems = new address[](materialItemCount);
        MaterialItem[] memory materialItemTokens = new MaterialItem[](
            materialItemCount
        );
        for (uint256 i = 0; i < materialItemCount; i++) {
            if (
                existedItemCollections.length > 0 &&
                i < existedItemCollections.length
            ) {
                MaterialItem instance = MaterialItem(existedItemCollections[i]);
                materialItems[i] = address(instance); // address
                materialItemTokens[i] = instance; // contract instance
            } else {
                uint256 j = i - existedItemCollections.length;
                MaterialItem instance = new MaterialItem(
                    newItemNames[j],
                    newItemSymbols[j],
                    "metadataUri",
                    address(this)
                ); // TODO: metadataUri는 setBaseUri()로 바꾸면 됨
                materialItems[i] = address(instance);
                materialItemTokens[i] = instance;
            }
            seasons[thisSeasonId].itemMaxSupplys[materialItems[i]] = maxSupplys[
                i
            ];

            seasons[thisSeasonId].itemMinted[materialItems[i]] = 0;
        }

        seasons[thisSeasonId].materialItems = materialItems;
        seasons[thisSeasonId].materialItemTokens = materialItemTokens;

        emit StartSeason(materialItems);
    }

    // zone 개수만큼 호출 필요(20번)
    /**
     *
     * @param zoneId 0 ~ 19
     * @param pieceCount zone 별 퍼즐 피스 수
     * @param requiredItemsForMinting  잠금해제에 필요한 아이템 토큰 주소
     * @param requiredItemAmount  잠금해제에 필요한 아이템 수
     * requiredItemsForMinting.length == requiredItemAmount.length
     */
    function setZoneData(
        uint8 zoneId,
        uint8 pieceCount,
        address[] calldata requiredItemsForMinting,
        uint8[] calldata requiredItemAmount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        seasons[thisSeasonId].pieceCountOfZones[zoneId] = pieceCount;
        seasons[thisSeasonId].requiredItemsForMinting[
                zoneId
            ] = requiredItemsForMinting;
        seasons[thisSeasonId].requiredItemAmount[zoneId] = requiredItemAmount;

        emit SetZoneData(
            zoneId,
            seasons[thisSeasonId].pieceCountOfZones[zoneId],
            seasons[thisSeasonId].requiredItemsForMinting[zoneId],
            seasons[thisSeasonId].requiredItemAmount[zoneId]
        );
    }

    function getRandomItem() public {
        // 2 DAL 차감
        require(dalToken.balanceOf(msg.sender) >= 2, "not enough balacnce");
        dalToken.burn(msg.sender, 2);

        // 랜덤 아이템 뽑기
        // 1. 설계도면 vs 재료
        uint256 materialItemCount = seasons[thisSeasonId].materialItems.length;
        address tokenAddress;
        uint tokenId;

        // 총 경우의 수 n+1 = 설계도면 1 + 재료아이템 materialItemCount(n)
        // 0 ~ (n-1) 중 0 인 경우에만 설계도면
        // n - 1 = materialItemCounts
        bool isMaterial = Utils.getRandomNumber(0, materialItemCount) > 0;

        if (isMaterial) {
            console.log("isMaterial");
            // 재료
            uint256 materialItemIndex = Utils.getRandomNumber(
                0,
                materialItemCount - 1
            );

            MaterialItem instance = seasons[thisSeasonId].materialItemTokens[
                materialItemIndex
            ];
            tokenAddress = seasons[thisSeasonId].materialItems[
                materialItemIndex
            ];
            tokenId = instance.mint(msg.sender);
            seasons[thisSeasonId].itemMinted[tokenAddress] =
                seasons[thisSeasonId].itemMinted[tokenAddress] +
                1;
        } else {
            console.log("isBlueprint");

            // 설계도면
            uint24 totalPieceCount = seasons[thisSeasonId].totalPieceCount;
            uint24[] memory remainedBlueprintIndexes = new uint24[](
                totalPieceCount
            );
            uint24 j = 0;

            for (uint24 i = 0; i < totalPieceCount; i++) {
                if (!seasons[thisSeasonId].mintedBlueprint[i]) {
                    remainedBlueprintIndexes[j] = i;
                    seasons[thisSeasonId].mintedBlueprint[i] = true;
                    j++;
                }
            }

            uint256 bluePrintItemIndex = Utils.getRandomNumber(0, j);

            tokenAddress = blueprintItemTokenAddress;
            tokenId = blueprintItemToken.mint(
                msg.sender,
                Strings.toString(bluePrintItemIndex)
            );
        }
        emit GetRandomItem(tokenAddress, tokenId, msg.sender);
    }

    // TODO: 시즌 데이터 조회(getThisSeasonData, getAllSeasonsData, getSeasonDataById)
    function getThisSeasonData()
        public
        view
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint24 seasonId)
    {
        return (thisSeasonId);
    }

    function getAllSeasonsData()
        public
        view
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint8[] memory _seasonIds)
    {
        return (seasonIds);
    }

    function getSeasonDataById(
        uint8 seasonId
    ) public view onlyRole(DEFAULT_ADMIN_ROLE) {}
}
