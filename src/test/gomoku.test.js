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

  test("register without flow", async () => {

    const alice = await getAccountAddress(adminAddressName)
    const args = [0]
    const signers = [alice]

    const [txResult, error] = await shallRevert(
      sendTransaction('Gomoku-register', signers, args)
    )
    expect(error).toContain(`assert(self.host.availableBalance > openingBet, message: \"Flow token is insufficient.\")`)
    expect(txResult).toBeNull()
  })

  test("register with enough flow", async () => {

    const aliceAddress = adminAddressName
    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5)
    await registerWithFlowByAddress(aliceAddress, 3)

  })

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
    expect(error1).toContain(`panic(\"Match failed.\")`)
  })

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
    console.log(txResult1, error1)
    expect(error1).toContain(`self.matchActive: \"Matching is not active.\"`)
  })

  test("match with match enable", async () => {
    const aliceAddress = adminAddressName

    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5.1)

    await registerWithFlowByAddress(aliceAddress, 3)

    const bobAddressName = "Bob"
    const bob = await getAccountAddress(bobAddressName)
    await serviceAccountMintTo(bob, 2)
    await matchGomokuAlongWithRegister(1, aliceAddress, bobAddressName, 2)
  })

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
    console.log(txResult, error)

    const signers1 = [bob]

    const [txResult1, error1] = await shallRevert(
      sendTransaction('Gomoku-match', signers1, [3])
    )
    console.log(txResult1, error1)
    expect(error1).toContain(`self.flowTokenVault.balance >= budget: \"Flow token not enough.\"`)
  })

  test("make moves", async () => {
    const alice = await getAccountAddress(adminAddressName)
    await serviceAccountMintTo(alice, 6)

    const aliceAddressName = adminAddressName
    await registerWithFlowByAddress(aliceAddressName, 3)

    const bobAddressName = "Bob"
    const bob = await getAccountAddress(bobAddressName)
    await serviceAccountMintTo(bob, 2)
    await matchGomokuAlongWithRegister(1, aliceAddressName, bobAddressName, 2)

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    console.log(aliceBalance)
    expect(aliceBalance).toEqual("1.00100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    console.log(bobBalance)
    expect(bobBalance).toEqual("0.00100000")

    const compositionIndex = 1
    let roundIndex = 0

    let bobMoves = [
      {
        x: 7,
        y: 7
      },
      {
        x: 8,
        y: 7
      },
      {
        x: 9,
        y: 7
      },
      {
        x: 10,
        y: 7
      },
      {
        x: 11,
        y: 7
      }
    ]

    let aliceMoves = [
      {
        x: 7,
        y: 8
      },
      {
        x: 8,
        y: 8
      },
      {
        x: 9,
        y: 8
      },
      {
        x: 10,
        y: 8
      }
    ]

    await simulateMoves(compositionIndex, roundIndex, aliceAddressName, bobAddressName, aliceMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult).toEqual({
      rawValue: Role.challenger
    })

    roundIndex++

    aliceMoves = [
      {
        x: 7,
        y: 8
      },
      {
        x: 8,
        y: 8
      },
      {
        x: 9,
        y: 8
      },
      {
        x: 10,
        y: 8
      },
      {
        x: 10,
        y: 9
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7
      },
      {
        x: 8,
        y: 7
      },
      {
        x: 9,
        y: 7
      },
      {
        x: 10,
        y: 7
      },
      {
        x: 11,
        y: 7
      }
    ]

    await simulateMoves(compositionIndex, roundIndex, aliceAddressName, bobAddressName, aliceMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    console.log(scriptResult2)
    expect(scriptResult2).toEqual({
      rawValue: Role.challenger
    })

    const [aliceBalance2, aliceBalanceError2] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError2).toBeNull()
    console.log(aliceBalance2)
    expect(aliceBalance2).toEqual("1.24100000")

    const [bobBalance2, bobBalanceError2] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError2).toBeNull()
    console.log(bobBalance2)
    expect(bobBalance2).toEqual("3.76100000")

  }, 5 * 60 * 1000)

})