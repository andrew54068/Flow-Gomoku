import path from "path";
import {
  emulator,
  init,
  getAccountAddress,
  deployContractByName
} from "@onflow/flow-js-testing";
import { deployMatcher, expectContractDeployed } from "./utils";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

describe("Deploy Contracts", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../cadence");

    await init(basePath)
    await emulator.start({
      logging: true,
    })
  });

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  test("Depoly MatchContract", async () => {

    await deployMatcher()

  })

  test("Depoly Gomoku", async () => {
    await deployMatcher()
    const to = await getAccountAddress("emulator-account")

    // We assume there is a file on "../cadence/contracts/MatchContract.cdc" path
    const names = [
      "FungibleToken",
      "NonFungibleToken",
      "TeleportedTetherToken",
      "BloctoToken"
    ]

    for (const name of names) {
      const [deploymentResult, error] = await deployContractByName({ to, name })
      expectContractDeployed(deploymentResult)
    }

    // We assume there is a file on "../cadence/contracts/Gomoku.cdc" path
    const name = "Gomoku"
    const [deploymentResult, error] = await deployContractByName({ to, name })
    expect(error).toBeNull()
    expectContractDeployed(deploymentResult)
  })
})