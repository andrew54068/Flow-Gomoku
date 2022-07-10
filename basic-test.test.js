import path from "path";
import { emulator, init, getAccountAddress } from "@onflow/flow-js-testing";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

describe("basic-test", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "./src/cadence");

    await init(basePath)
    await emulator.start({
      logging: true,
    })
  });

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  });

  test("account", async () => {

    const Alice = await getAccountAddress("emulator-account")
    console.log({ Alice })

  })
})