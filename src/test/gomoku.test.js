import path from "path";
import {
  emulator,
  init,
  getAccountAddress,
  executeScript,
  sendTransaction,
  shallPass,
  shallRevert,
  deployContractByName
} from "@onflow/flow-js-testing";
import { expectContractDeployed } from "./utils";

describe("Gomoku", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../cadence");

    await init(basePath)
    await emulator.start({
      logging: false,
    })

    const to = await getAccountAddress("Alice")

    const names = [
      'MatchContract',
      'GomokuType',
      'GomokuResulting',
      'GomokuResult',
      'GomokuIdentifying',
      'GomokuIdentity',
      'Gomokuing',
      'Gomoku'
    ]

    for (const name of names) {
      const [deploymentResult, error] = await deployContractByName({ to, name })
      expect(error).toBeNull()
      expectContractDeployed(deploymentResult, name)
    }

  });

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  test("register without flow", async () => {

    const alice = await getAccountAddress("Alice")
    const args = [0]
    const signers = [alice]

    const [txResult, error] = await shallRevert(
      sendTransaction('Gomoku-register', signers, args)
    )
    console.log(txResult, error)

  })

  test("register with enough flow", async () => {

    const alice = await getAccountAddress("Alice")

    const serviceAccount = ['0xf8d6e0586b0a20c7']
    const mintArgs = [alice, 5]

    const [mintResult, mintError] = await shallPass(
      sendTransaction('Mint-flow', serviceAccount, mintArgs)
    )
    expect(mintError).toBeNull()
    console.log(mintResult)

    const args = []
    const signers = [alice]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

    const args1 = [3]
    const signers1 = [alice]

    const [txResult1, error1] = await shallPass(
      sendTransaction('Gomoku-register', signers1, args1)
    )
    console.log(txResult1, error1)

  })

})