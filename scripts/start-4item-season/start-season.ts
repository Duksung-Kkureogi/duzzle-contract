import { ethers } from "hardhat";
import { EventTopic } from "../../test/enum/test";
import { SeasonData } from "../../test/data/playduzzle/input-data-class/season";
import { SimpleSeasonData } from "./input-data";
import { DefaultDuzzleData } from "../../test/data/playduzzle/input-data-class/constants";


const playDuzzleContractAddress = "";

async function main() {
  const playDuzzleContract = (
    await ethers.getContractFactory("PlayDuzzle")
  ).attach(playDuzzleContractAddress);

  const firstSeasonData = new SeasonData(SimpleSeasonData.seasonData1);

  const receipt = await (
    await playDuzzleContract.startSeason(
      ...firstSeasonData.startSeasonParameters
    )
  ).wait();
  console.log("===receipt: ", receipt);

  const materialItemTokenAddresses: string[] = (receipt?.logs.find(
    (e: any) => e.topics[0] === EventTopic.StartSeason
  )).args[0];

  console.log("===materialItemTokenAddresses: ", materialItemTokenAddresses);

  firstSeasonData.makeZoneDataParameters(materialItemTokenAddresses);

  const setZoneDatas = new Array(DefaultDuzzleData.ZoneCount)
    .fill(null)
    .map((_e, i) =>
      playDuzzleContract.setZoneData(
        ...firstSeasonData.setZoneDataParametersArr![i]
      )
    );
  await Promise.allSettled(setZoneDatas);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
