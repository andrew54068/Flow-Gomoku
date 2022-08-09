import path from "path";
import {
  emulator,
  init
} from "@onflow/flow-js-testing";
import { deployContract } from "./utils";

describe("Gomoku", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../cadence");

    await init(basePath)
    await emulator.start({
      logging: false,
    })


    await deployContract('MatchContract')
    await deployContract('GomokuType')
    await deployContract('GomokuResulting')
    await deployContract('GomokuResult')
    await deployContract('GomokuIdentifying')
    await deployContract('GomokuIdentity')
    await deployContract('Gomokuing')
    await deployContract('Gomoku')

  });

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  test("match successfully", async () => {

  })
})