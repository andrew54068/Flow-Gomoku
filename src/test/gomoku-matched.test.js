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

const adminAddressName = "Alice"

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

  const serviceAccountMintTo = async (receiver, amount) => {
    const serviceAccount = ['0xf8d6e0586b0a20c7']
    const mintArgs = [receiver, amount]

    const [mintResult, mintError] = await shallPass(
      sendTransaction('Mint-flow', serviceAccount, mintArgs)
    )
    expect(mintError).toBeNull()
    console.log(mintResult)
  }

  const registerWithFlowByAddress = async (addressName, bet) => {

    const admin = await getAccountAddress(adminAddressName)
    const args = []
    const signers = [admin]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    expect(error).toBeNull()
    console.log(txResult, error)

    const account = await getAccountAddress(addressName)
    const args1 = [bet]
    const signers1 = [account]

    const [txResult1, error1] = await shallPass(
      sendTransaction('Gomoku-register', signers1, args1)
    )
    expect(error1).toBeNull()
    console.log(txResult1, error1)
  }

  const matching = async (challenger, budget) => {
    const admin = await getAccountAddress(adminAddressName)
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

  const matchGomokuAlongWithRegister = async (hostAddressName, bet) => {
    await registerWithFlowByAddress(hostAddressName, bet)

    const host = await getAccountAddress(hostAddressName)

    const bob = await getAccountAddress("Bob")

    await serviceAccountMintTo(bob, bet)

    await matching(bob, bet)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-composition-ref', [1])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult["host"]).toBe(host)
    expect(scriptResult["challenger"]).toBe(bob)
    expect(scriptResult["currentRound"]).toBe(0)
    expect(scriptResult["id"]).toBe(1)
    expect(Object.keys(scriptResult["locationStoneMaps"]).length).toBe(2)
    expect(scriptResult["roundWiners"]).toEqual([])
    expect(scriptResult["steps"]).toEqual([[], []])
    expect(scriptResult["totalRound"]).toBe(2)
    expect(scriptResult["winner"]).toBeNull()

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-participants', [1])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toEqual([host, bob])

    const [scriptResult3, scriptError3] = await executeScript('Gomoku-get-opening-bet', [1])
    expect(scriptError3).toBeNull()
    expect(scriptResult3).toBe(`${bet * 2}.00000000`)

    const [scriptResult4, scriptError4] = await executeScript('Gomoku-get-valid-bets', [1])
    expect(scriptError4).toBeNull()
    expect(scriptResult4).toBe(`${bet * 2}.00000000`)
  }

  test("match with match enable", async () => {
    const aliceAddress = adminAddressName

    const alice = await getAccountAddress(aliceAddress)

    await serviceAccountMintTo(alice, 5.1)

    await registerWithFlowByAddress(aliceAddress, 3)

    await matchGomokuAlongWithRegister(aliceAddress, 2)
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

  const StoneColor = {
    black: 0,
    white: 1
  }

  const Role = {
    host: 0,
    challenger: 1
  }

  const makeMove = async (player, index, round, stone, raiseBet, expectStoneData) => {
    const args = [index, stone.x, stone.y, raiseBet]
    const signers = [player]
    const limit = 9999

    const [txResult, error] = await shallPass(
      sendTransaction('Gomoku-make-move', signers, args, limit)
    )
    expect(error).toBeNull()
    console.log(txResult, error)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-stone-data', [index, round])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult).toEqual(expectStoneData)
  }

  const simulateMoves = async (compositionIndex, roundIndex, host, bobMoves, aliceMoves) => {
    const alice = await getAccountAddress(adminAddressName)
    const bob = await getAccountAddress("Bob")
    let firstTaker
    let secondTaker
    let firstTakerMoves = []
    let secondTakerMoves = []
    if (host == alice) {
      if (roundIndex % 2 == 0) {
        firstTaker = bob
        secondTaker = alice
        firstTakerMoves = bobMoves
        secondTakerMoves = aliceMoves
      } else {
        firstTaker = alice
        secondTaker = bob
        firstTakerMoves = aliceMoves
        secondTakerMoves = bobMoves
      }
    } else {
      if (roundIndex % 2 == 0) {
        firstTaker = alice
        secondTaker = bob
        firstTakerMoves = aliceMoves
        secondTakerMoves = bobMoves
      } else {
        firstTaker = bob
        secondTaker = alice
        firstTakerMoves = bobMoves
        secondTakerMoves = aliceMoves
      }
    }
    let moves = []
    for (let step = 0; step < bobMoves.length; step++) {
      const firstTakerMove = firstTakerMoves[step]
      if (firstTakerMove) {
        moves.push(
          {
            color: {
              rawValue: StoneColor.black
            },
            location: {
              x: firstTakerMove.x,
              y: firstTakerMove.y
            }
          }
        )
        await makeMove(firstTaker, compositionIndex, roundIndex, {
          color: StoneColor.black,
          x: firstTakerMove.x,
          y: firstTakerMove.y
        }, 0, moves)
      }
      const secondTakerMove = secondTakerMoves[step]
      if (secondTakerMove) {
        moves.push(
          {
            color: {
              rawValue: StoneColor.white
            },
            location: {
              x: secondTakerMove.x,
              y: secondTakerMove.y
            }
          }
        )
        await makeMove(secondTaker, compositionIndex, roundIndex, {
          color: StoneColor.white,
          x: secondTakerMove.x,
          y: secondTakerMove.y
        }, 0, moves)
      }
    }
  }

  test("make moves", async () => {
    const alice = await getAccountAddress(adminAddressName)
    await serviceAccountMintTo(alice, 6)

    const aliceAddressName = adminAddressName
    await registerWithFlowByAddress(aliceAddressName, 3)

    await matchGomokuAlongWithRegister(aliceAddressName, 2)

    const bob = await getAccountAddress("Bob")

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

    await simulateMoves(compositionIndex, roundIndex, alice, bobMoves, aliceMoves)

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

    await simulateMoves(compositionIndex, roundIndex, alice, bobMoves, aliceMoves)

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