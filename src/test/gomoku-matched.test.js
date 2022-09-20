import path from "path";
import {
  emulator,
  init,
  getAccountAddress,
  executeScript,
  sendTransaction,
  shallPass,
  deployContractByName
} from "@onflow/flow-js-testing";
import {
  adminAddressName,
  expectContractDeployed,
  matchGomokuAlongWithRegister,
  Result,
  roundDrawSteps,
  roundDrawSteps2,
  serviceAccountMintTo,
  simulateMoves
} from "./utils";

const joeAddressName = 'Joe'
const bobAddressName = 'Bob'

describe("Gomoku after matched", () => {
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

    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)

    await serviceAccountMintTo(joe, 11)
    await serviceAccountMintTo(bob, 10)

    const alice = admin
    const [aliceBalance2, aliceBalanceError2] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError2).toBeNull()
    expect(aliceBalance2).toEqual("0.00100000")

    const [joeBalance2, joeBalanceError2] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError2).toBeNull()
    expect(joeBalance2).toEqual("11.00100000")

    const [bobBalance2, bobBalanceError2] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError2).toBeNull()
    expect(bobBalance2).toEqual("10.00100000")

    await matchGomokuAlongWithRegister(0, joeAddressName, bobAddressName, 10)

  }, 5 * 60 * 1000);

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  test("challenger wins", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)
    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
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

    let joeMoves = [
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

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    expect(scriptResult).toEqual({
      rawValue: Result.challengerWins
    })

    roundIndex++

    joeMoves = [
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

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toEqual({
      rawValue: Result.challengerWins
    })

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    expect(aliceBalance).toEqual("1.00100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError).toBeNull()
    expect(joeBalance).toEqual("1.20100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    expect(bobBalance).toEqual("18.80100000")
    
    const joeResultArg = [joe, compositionIndex]
    const [joeResult, joeResultError] = await executeScript('Gomoku-result-get-token', joeResultArg)
    expect(joeResultError).toBeNull()
    expect(joeResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(joeResult["isDraw"]).toBe(false)
    expect(joeResult["gain"]).toEqual("0.20000000")

    const bobResultArg = [bob, compositionIndex]
    const [bobResult, bobResultError] = await executeScript('Gomoku-result-get-token', bobResultArg)
    expect(bobResultError).toBeNull()
    expect(bobResult["id"]).toBe(compositionIndex)
    expect(bobResult["winner"]).toBe(bob)
    expect(bobResult["losser"]).toBe(joe)
    expect(bobResult["isDraw"]).toBe(false)
    expect(bobResult["gain"]).toEqual("18.80000000")

  }, 5 * 60 * 1000)

  test("host wins", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)

    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
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
        y: 6
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8
      },
      {
        x: 8,
        y: 9
      },
      {
        x: 9,
        y: 10
      },
      {
        x: 10,
        y: 11
      },
      {
        x: 11,
        y: 12
      }
    ]

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    expect(scriptResult).toEqual({
      rawValue: Result.hostWins
    })

    roundIndex++

    joeMoves = [
      {
        x: 8,
        y: 7
      },
      {
        x: 7,
        y: 6
      },
      {
        x: 6,
        y: 5
      },
      {
        x: 5,
        y: 4
      },
      {
        x: 4,
        y: 3
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7
      },
      {
        x: 4,
        y: 7
      },
      {
        x: 9,
        y: 7
      },
      {
        x: 10,
        y: 7
      }
    ]

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toEqual({
      rawValue: Result.hostWins
    })

    const [aliceBalance2, aliceBalanceError2] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError2).toBeNull()
    expect(aliceBalance2).toEqual("1.00100000")

    const [joeBalance2, joeBalanceError2] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError2).toBeNull()
    expect(joeBalance2).toEqual("20.00100000")

    const [bobBalance2, bobBalanceError2] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError2).toBeNull()
    expect(bobBalance2).toEqual("0.00100000")

    const joeResultArg = [joe, compositionIndex]
    const [joeResult, joeResultError] = await executeScript('Gomoku-result-get-token', joeResultArg)
    expect(joeResultError).toBeNull()
    expect(joeResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(joe)
    expect(joeResult["losser"]).toBe(bob)
    expect(joeResult["isDraw"]).toBe(false)
    expect(joeResult["gain"]).toEqual("19.00000000")

    const bobResultArg = [bob, compositionIndex]
    const [bobResult, bobResultError] = await executeScript('Gomoku-result-get-token', bobResultArg)
    expect(bobResultError).toBeNull()
    expect(bobResult["id"]).toBe(compositionIndex)
    expect(bobResult["winner"]).toBe(joe)
    expect(bobResult["losser"]).toBe(bob)
    expect(bobResult["isDraw"]).toBe(false)
    expect(bobResult["gain"]).toEqual("0.00000000")

  }, 5 * 60 * 1000)

  test("draw", async () => {

    const compositionIndex = 0
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

    let joeMoves = [
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

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    expect(scriptResult).toEqual({
      rawValue: Result.challengerWins
    })

    roundIndex++

    joeMoves = [
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

    bobMoves = [
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

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toEqual({
      rawValue: Result.hostWins
    })

    const alice = await getAccountAddress(adminAddressName)
    const [aliceBalance2, aliceBalanceError2] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError2).toBeNull()
    expect(aliceBalance2).toEqual("0.40100000")

    const joe = await getAccountAddress(joeAddressName)
    const [joeBalance2, joeBalanceError2] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError2).toBeNull()
    expect(joeBalance2).toEqual("10.80100000")

    const bob = await getAccountAddress(bobAddressName)
    const [bobBalance2, bobBalanceError2] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError2).toBeNull()
    expect(bobBalance2).toEqual("9.80100000")

    const joeResultArg = [joe, compositionIndex]
    const [joeResult, joeResultError] = await executeScript('Gomoku-result-get-token', joeResultArg)
    expect(joeResultError).toBeNull()
    expect(joeResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBeNull()
    expect(joeResult["losser"]).toBeNull()
    expect(joeResult["isDraw"]).toBe(true)
    expect(joeResult["gain"]).toEqual("0.00000000")

    const bobResultArg = [bob, compositionIndex]
    const [bobResult, bobResultError] = await executeScript('Gomoku-result-get-token', bobResultArg)
    expect(bobResultError).toBeNull()
    expect(bobResult["id"]).toBe(compositionIndex)
    expect(bobResult["winner"]).toBeNull()
    expect(bobResult["losser"]).toBeNull()
    expect(bobResult["isDraw"]).toBe(true)
    expect(bobResult["gain"]).toEqual("0.00000000")

  }, 5 * 60 * 1000)

  test("host wins due to challenger surrender twice", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)
    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
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
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8
      },
      {
        x: 8,
        y: 9
      },
      {
        x: 9,
        y: 10
      }
    ]

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    expect(scriptResult).toBeNull()

    const signers = [bob]
    const args = [compositionIndex]

    const [txResult, error] = await shallPass(
      sendTransaction('Gomoku-surrender', signers, args)
    )
    expect(error).toBeNull()

    roundIndex++

    joeMoves = [
      {
        x: 8,
        y: 7
      },
      {
        x: 7,
        y: 6
      },
      {
        x: 6,
        y: 5
      },
      {
        x: 5,
        y: 4
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7
      },
      {
        x: 4,
        y: 7
      },
      {
        x: 9,
        y: 7
      }
    ]

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toBeNull()

    const signers2 = [bob]
    const args2 = [compositionIndex]

    const [txResult2, error2] = await shallPass(
      sendTransaction('Gomoku-surrender', signers2, args2)
    )
    expect(error2).toBeNull()

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    expect(aliceBalance).toEqual("1.00100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError).toBeNull()
    expect(joeBalance).toEqual("20.00100000")
    
    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    expect(bobBalance).toEqual("0.00100000")

    const joeResultArg = [joe, compositionIndex]
    const [joeResult, joeResultError] = await executeScript('Gomoku-result-get-token', joeResultArg)
    expect(joeResultError).toBeNull()
    expect(joeResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(joe)
    expect(joeResult["losser"]).toBe(bob)
    expect(joeResult["isDraw"]).toBe(false)
    expect(joeResult["gain"]).toEqual("19.00000000")

    const bobResultArg = [bob, compositionIndex]
    const [bobResult, bobResultError] = await executeScript('Gomoku-result-get-token', bobResultArg)
    expect(bobResultError).toBeNull()
    expect(bobResult["id"]).toBe(compositionIndex)
    expect(bobResult["winner"]).toBe(joe)
    expect(bobResult["losser"]).toBe(bob)
    expect(bobResult["isDraw"]).toBe(false)
    expect(bobResult["gain"]).toEqual("0.00000000")

  }, 5 * 60 * 1000)

  test("challenger wins due to challenger surrender first round", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)
    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
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
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8
      },
      {
        x: 8,
        y: 9
      },
      {
        x: 9,
        y: 10
      }
    ]

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    expect(scriptResult).toBeNull()

    const signers = [joe]
    const args = [compositionIndex]

    const [txResult, error] = await shallPass(
      sendTransaction('Gomoku-surrender', signers, args)
    )
    expect(error).toBeNull()

    roundIndex++

    joeMoves = [
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

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toEqual({
      rawValue: Result.challengerWins
    })

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    expect(aliceBalance).toEqual("1.00100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError).toBeNull()
    expect(joeBalance).toEqual("1.20100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    expect(bobBalance).toEqual("18.80100000")

    const joeResultArg = [joe, compositionIndex]
    const [joeResult, joeResultError] = await executeScript('Gomoku-result-get-token', joeResultArg)
    expect(joeResultError).toBeNull()
    expect(joeResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(joeResult["isDraw"]).toBe(false)
    expect(joeResult["gain"]).toEqual("0.20000000")

    const bobResultArg = [bob, compositionIndex]
    const [bobResult, bobResultError] = await executeScript('Gomoku-result-get-token', bobResultArg)
    expect(bobResultError).toBeNull()
    expect(bobResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(bobResult["isDraw"]).toBe(false)
    expect(bobResult["gain"]).toEqual("18.80000000")

  }, 5 * 60 * 1000)

  test("challenger wins due to challenger surrender second round", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)
    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
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

    let joeMoves = [
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

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    expect(scriptResult).toEqual({
      rawValue: Result.challengerWins
    })

    roundIndex++

    joeMoves = [
      {
        x: 8,
        y: 7
      },
      {
        x: 7,
        y: 6
      },
      {
        x: 6,
        y: 5
      },
      {
        x: 5,
        y: 4
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7
      },
      {
        x: 4,
        y: 7
      },
      {
        x: 9,
        y: 7
      }
    ]

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toBeNull()

    const signers2 = [joe]
    const args2 = [compositionIndex]

    const [txResult2, error2] = await shallPass(
      sendTransaction('Gomoku-surrender', signers2, args2)
    )
    expect(error2).toBeNull()

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    expect(aliceBalance).toEqual("1.00100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError).toBeNull()
    expect(joeBalance).toEqual("1.20100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    expect(bobBalance).toEqual("18.80100000")

    const joeResultArg = [joe, compositionIndex]
    const [joeResult, joeResultError] = await executeScript('Gomoku-result-get-token', joeResultArg)
    expect(joeResultError).toBeNull()
    expect(joeResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(joeResult["isDraw"]).toBe(false)
    expect(joeResult["gain"]).toEqual("0.20000000")

    const bobResultArg = [bob, compositionIndex]
    const [bobResult, bobResultError] = await executeScript('Gomoku-result-get-token', bobResultArg)
    expect(bobResultError).toBeNull()
    expect(bobResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(bobResult["isDraw"]).toBe(false)
    expect(bobResult["gain"]).toEqual("18.80000000")

  }, 5 * 60 * 1000)

  test("challenger wins due to draw in first round", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)
    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
    let roundIndex = 0

    let bobMoves = roundDrawSteps

    let joeMoves = roundDrawSteps2

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    expect(scriptResult).toEqual({
      rawValue: Result.draw
    })

    roundIndex++

    joeMoves = [
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

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toEqual({
      rawValue: Result.challengerWins
    })

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    expect(aliceBalance).toEqual("1.00100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError).toBeNull()
    expect(joeBalance).toEqual("1.20100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    expect(bobBalance).toEqual("18.80100000")

    const joeResultArg = [joe, compositionIndex]
    const [joeResult, joeResultError] = await executeScript('Gomoku-result-get-token', joeResultArg)
    expect(joeResultError).toBeNull()
    expect(joeResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(joeResult["isDraw"]).toBe(false)
    expect(joeResult["gain"]).toEqual("0.20000000")

    const bobResultArg = [bob, compositionIndex]
    const [bobResult, bobResultError] = await executeScript('Gomoku-result-get-token', bobResultArg)
    expect(bobResultError).toBeNull()
    expect(bobResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(bobResult["isDraw"]).toBe(false)
    expect(bobResult["gain"]).toEqual("18.80000000")

  }, 5 * 60 * 1000)

  test("challenger wins due to draw in second round", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)
    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
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

    let joeMoves = [
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

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    expect(scriptResult).toEqual({
      rawValue: Result.challengerWins
    })

    roundIndex++

    bobMoves = roundDrawSteps2

    joeMoves = roundDrawSteps

    await simulateMoves(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toEqual({
      rawValue: Result.draw
    })

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    expect(aliceBalance).toEqual("1.00100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError).toBeNull()
    expect(joeBalance).toEqual("1.20100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    expect(bobBalance).toEqual("18.80100000")

    const joeResultArg = [joe, compositionIndex]
    const [joeResult, joeResultError] = await executeScript('Gomoku-result-get-token', joeResultArg)
    expect(joeResultError).toBeNull()
    expect(joeResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(joeResult["isDraw"]).toBe(false)
    expect(joeResult["gain"]).toEqual("0.20000000")

    const bobResultArg = [bob, compositionIndex]
    const [bobResult, bobResultError] = await executeScript('Gomoku-result-get-token', bobResultArg)
    expect(bobResultError).toBeNull()
    expect(bobResult["id"]).toBe(compositionIndex)
    expect(joeResult["winner"]).toBe(bob)
    expect(joeResult["losser"]).toBe(joe)
    expect(bobResult["isDraw"]).toBe(false)
    expect(bobResult["gain"]).toEqual("18.80000000")

  }, 5 * 60 * 1000)

})