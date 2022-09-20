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
import {
  adminAddressName,
  expectContractDeployed,
  matchGomokuAlongWithRegister,
  registerWithFlowByAddress,
  Role,
  serviceAccountMintTo,
  simulateMoves
} from "./utils";

describe("Gomoku", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../cadence");

    await init(basePath)
    await emulator.start({
      logging: false,
    })

    const admin = await getAccountAddress(adminAddressName)

    const names = [
      'MatchContract',
      'GomokuType',
      'GomokuResult',
      'GomokuIdentity',
      'Gomoku'
    ]

    for (const name of names) {
      const [deploymentResult, error] = await deployContractByName({ to: admin, name })
      expect(error).toBeNull()
      expectContractDeployed(deploymentResult, name)
    }

  }, 5 * 60 * 1000);

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  test("register without flow", async () => {

    const alice = await getAccountAddress(adminAddressName)
    const args = [0]
    const signers = [alice]

    const [txResult, error] = await shallRevert(
      sendTransaction('Gomoku-register', signers, args)
    )
    expect(error).toContain(`assert(self.host.availableBalance > openingBet, message: \"Flow token is insufficient.\")`)
    expect(txResult).toBeNull()
  }, 10 * 1000)

  test("register with enough flow", async () => {

    const aliceAddress = adminAddressName
    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5)
    await registerWithFlowByAddress(aliceAddress, 3)

  }, 10 * 1000)

  test("match without flow", async () => {
    const aliceAddress = adminAddressName
    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5)
    await registerWithFlowByAddress(aliceAddress, 3)
    await registerWithFlowByAddress(aliceAddress, 1)

    const bob = await getAccountAddress("Bob")

    const signers1 = [bob]

    const [txResult1, error1] = await shallRevert(
      sendTransaction('Gomoku-match', signers1, [0])
    )
    expect(error1).toContain(`Match failed at index`)
  }, 10 * 1000)

  test("match with matching not enable", async () => {
    const aliceAddress = adminAddressName
    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5)
    await registerWithFlowByAddress(aliceAddress, 3)
    await registerWithFlowByAddress(aliceAddress, 1)

    const bob = await getAccountAddress("Bob")

    await serviceAccountMintTo(bob, 3)

    const signers1 = [bob]

    const [txResult1, error1] = await shallRevert(
      sendTransaction('Gomoku-match', signers1, [3])
    )
    expect(error1).toContain(`self.matchActive: \"Matching is not active.\"`)
  }, 10 * 1000)

  test("match with match enable", async () => {
    const aliceAddress = adminAddressName

    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5.1)

    await registerWithFlowByAddress(aliceAddress, 3)

    const bobAddressName = "Bob"
    const bob = await getAccountAddress(bobAddressName)
    await serviceAccountMintTo(bob, 2)
    await matchGomokuAlongWithRegister(1, aliceAddress, bobAddressName, 2)
  }, 10 * 1000)

  test("match by index with match enable", async () => {
    const aliceAddress = adminAddressName

    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5.1)

    await registerWithFlowByAddress(aliceAddress, 2.5)
    await registerWithFlowByAddress(aliceAddress, 2)

    const bobAddressName = "Bob"
    const bob = await getAccountAddress(bobAddressName)
    await serviceAccountMintTo(bob, 2)

    const admin = await getAccountAddress(adminAddressName)
    const args = []
    const signers = [admin]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-match', signers, args)
    )
    expect(error).toBeNull()

    const challenger = [bob]
    const budget = 2
    const index = 1
    const args2 = [budget, index]

    const [txResult1, error1] = await shallPass(
      sendTransaction('Gomoku-match-by-index', challenger, args2)
    )
    expect(error1).toBeNull()
  }, 10 * 1000)

  test("match with match enable budget not enough", async () => {

    const aliceAddress = adminAddressName
    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5)
    await registerWithFlowByAddress(aliceAddress, 3)
    await registerWithFlowByAddress(aliceAddress, 1)

    const bob = await getAccountAddress("Bob")

    await serviceAccountMintTo(bob, 2)

    const admin = await getAccountAddress(adminAddressName)
    const args = []
    const signers = [admin]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-match', signers, args)
    )
    expect(error).toBeNull()

    const signers1 = [bob]

    const [txResult1, error1] = await shallRevert(
      sendTransaction('Gomoku-match', signers1, [3])
    )
    expect(error1).toContain(`self.flowTokenVault.balance >= budget: \"Flow token not enough.\"`)
  }, 10 * 1000)

})