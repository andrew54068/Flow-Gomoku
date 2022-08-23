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

const adminAddress = "Alice"

describe("Gomoku", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../cadence");

    await init(basePath)
    await emulator.start({
      logging: false,
    })

    const admin = await getAccountAddress(adminAddress)

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
      const [deploymentResult, error] = await deployContractByName({ to: admin, name })
      expect(error).toBeNull()
      expectContractDeployed(deploymentResult, name)
    }

  });

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  const serviceAccountMintTo = async (receiver, amount) => {
    const serviceAccount = ['0xf8d6e0586b0a20c7']
    const mintArgs = [receiver, amount]

    const [mintResult, mintError] = await shallPass(
      sendTransaction('Mint-flow', serviceAccount, mintArgs)
    )
    expect(mintError).toBeNull()
    console.log(mintResult)
  }

  const registerWithFlow = async (bet) => {
    const admin = await getAccountAddress(adminAddress)

    await serviceAccountMintTo(admin, 5)

    const args = []
    const signers = [admin]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    expect(error).toBeNull()
    console.log(txResult, error)

    const args1 = [bet]
    const signers1 = [admin]

    const [txResult1, error1] = await shallPass(
      sendTransaction('Gomoku-register', signers1, args1)
    )
    expect(error1).toBeNull()
    console.log(txResult1, error1)
  }

  const matching = async (challenger, budget) => {
    const admin = await getAccountAddress(adminAddress)
    const args = []
    const signers = [admin]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-match', signers, args)
    )
    expect(error).toBeNull()
    console.log(txResult, error)

    const signers1 = [challenger]

    const [txResult1, error1] = await shallPass(
      sendTransaction('Gomoku-match', signers1, [budget])
    )
    expect(error1).toBeNull()
    console.log(txResult1, error1)
  }

  test("register without flow", async () => {

    const alice = await getAccountAddress(adminAddress)
    const args = [0]
    const signers = [alice]

    const [txResult, error] = await shallRevert(
      sendTransaction('Gomoku-register', signers, args)
    )
    expect(error).toContain(`assert(self.host.availableBalance > openingBet, message: \"Flow token is insufficient.\")`)
  })

  test("register with enough flow", async () => {

    await registerWithFlow(3)

  })

  test("match without flow", async () => {

    await registerWithFlow(3)
    await registerWithFlow(1)

    const bob = await getAccountAddress("Bob")

    const signers1 = [bob]

    const [txResult1, error1] = await shallRevert(
      sendTransaction('Gomoku-match', signers1, [0])
    )
    expect(error1).toContain(`panic(\"Match failed.\")`)
  })

  test("match with matching not enable", async () => {

    await registerWithFlow(3)
    await registerWithFlow(1)

    const bob = await getAccountAddress("Bob")

    await serviceAccountMintTo(bob, 3)

    const signers1 = [bob]

    const [txResult1, error1] = await shallRevert(
      sendTransaction('Gomoku-match', signers1, [3])
    )
    console.log(txResult1, error1)
    expect(error1).toContain(`self.matchActive: \"Matching is not active.\"`)
  })

  test("match with match enable", async () => {

    await registerWithFlow(3)
    await registerWithFlow(1)

    const admin = await getAccountAddress(adminAddress)

    const bob = await getAccountAddress("Bob")

    await serviceAccountMintTo(bob, 2)

    await matching(bob, 2)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-composition-ref', [1])
    expect(scriptError).toBeNull()
    expect(scriptResult["host"]).toBe(admin)
    expect(scriptResult["challenger"]).toBe(bob)
    expect(scriptResult["currentRound"]).toBe(0)
    expect(scriptResult["id"]).toBe(1)
    expect(Object.keys(scriptResult["locationStoneMap"]).length).toBe(0)
    expect(scriptResult["roundWiners"]).toEqual([])
    expect(scriptResult["steps"]).toEqual([])
    expect(scriptResult["totalRound"]).toBe(2)
    expect(scriptResult["winner"]).toBeNull()

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-participants', [1])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toEqual([admin, bob])

    const [scriptResult3, scriptError3] = await executeScript('Gomoku-get-opening-bet', [1])
    expect(scriptError3).toBeNull()
    expect(scriptResult3).toBe("2.00000000")

    const [scriptResult4, scriptError4] = await executeScript('Gomoku-get-valid-bets', [1])
    expect(scriptError4).toBeNull()
    expect(scriptResult4).toBe("2.00000000")

  })

  test("match with match enable budget not enough", async () => {

    await registerWithFlow(3)
    await registerWithFlow(1)

    const bob = await getAccountAddress("Bob")

    await serviceAccountMintTo(bob, 2)

    const admin = await getAccountAddress(adminAddress)
    const args = []
    const signers = [admin]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-match', signers, args)
    )
    expect(error).toBeNull()
    console.log(txResult, error)

    const signers1 = [bob]

    const [txResult1, error1] = await shallRevert(
      sendTransaction('Gomoku-match', signers1, [3])
    )
    console.log(txResult1, error1)
    expect(error1).toContain(`self.flowTokenVault.balance >= budget: \"Flow token not enough.\"`)
  })

})