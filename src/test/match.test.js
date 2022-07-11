import path from "path";
import {
  emulator,
  init,
  getAccountAddress,
  sendTransaction,
  shallPass,
  shallRevert
} from "@onflow/flow-js-testing";
import { deployMatcher } from "./utils";

describe("Matcher", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../cadence");

    await init(basePath)
    await emulator.start({
      logging: true,
    })

    await deployMatcher()
  });

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  test("Register not active", async () => {

    const to = await getAccountAddress("emulator-account")
    const args = []
    const signers = [to]

    const [txResult, error] = await shallRevert(
      sendTransaction('TestMatcher-register-not-active', signers, args)
    )
    console.log(txResult, error)

  })

  test("Register active", async () => {

    const to = await getAccountAddress("emulator-account")
    const args = []
    const signers = [to]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-register-active', signers, args)
    )
    console.log(txResult, error)

  })
})