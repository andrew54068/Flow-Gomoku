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
  makeMove,
  matchGomokuAlongWithRegister,
  Result,
  roundDrawSteps,
  roundDrawSteps2,
  serviceAccountMintTo,
  simulateMovesWithRaise,
  StoneColor
} from "./utils";

const joeAddressName = 'Joe'
const bobAddressName = 'Bob'

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

    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)

    await serviceAccountMintTo(joe, 21)
    await serviceAccountMintTo(bob, 20)

    const alice = admin
    const [aliceBalance2, aliceBalanceError2] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError2).toBeNull()
    console.log(aliceBalance2)
    expect(aliceBalance2).toEqual("0.00100000")

    const [joeBalance2, joeBalanceError2] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError2).toBeNull()
    console.log(joeBalance2)
    expect(joeBalance2).toEqual("21.00100000")

    const [bobBalance2, bobBalanceError2] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError2).toBeNull()
    console.log(bobBalance2)
    expect(bobBalance2).toEqual("20.00100000")

    await matchGomokuAlongWithRegister(0, joeAddressName, bobAddressName, 10)

  }, 5 * 60 * 1000);

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  test("challenger wins without matched raise bet", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)
    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
    let roundIndex = 0

    let bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 1
      },
      {
        x: 8,
        y: 7,
        raiseBet: 1
      },
      {
        x: 9,
        y: 7,
        raiseBet: 1
      },
      {
        x: 10,
        y: 7,
        raiseBet: 1
      },
      {
        x: 11,
        y: 7,
        raiseBet: 1
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 0
      },
      {
        x: 8,
        y: 8,
        raiseBet: 0
      },
      {
        x: 9,
        y: 8,
        raiseBet: 0
      },
      {
        x: 10,
        y: 8,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets, hostBetsError] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError).toBeNull()
    expect(hostBets).toEqual([
      '10.00000000',
      '0.00000000'
    ])

    const [challengerBets, challengerBetsError] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError).toBeNull()
    expect(challengerBets).toEqual([
      '10.00000000',
      '5.00000000'
    ])

    const [validBet, validBetError] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError).toBeNull()
    expect(validBet).toBe(`20.00000000`)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult).toEqual({
      rawValue: Result.challengerWins
    })

    roundIndex++

    joeMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 0
      },
      {
        x: 8,
        y: 8,
        raiseBet: 0
      },
      {
        x: 9,
        y: 8,
        raiseBet: 0
      },
      {
        x: 10,
        y: 8,
        raiseBet: 0
      },
      {
        x: 10,
        y: 9,
        raiseBet: 0
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 0
      },
      {
        x: 8,
        y: 7,
        raiseBet: 0
      },
      {
        x: 9,
        y: 7,
        raiseBet: 0
      },
      {
        x: 10,
        y: 7,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets2, hostBetsError2] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError2).toBeNull()
    expect(hostBets2).toEqual([
      '10.00000000',
      '0.00000000'
    ])

    const [challengerBets2, challengerBetsError2] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError2).toBeNull()
    expect(challengerBets2).toEqual([
      '10.00000000',
      '5.00000000'
    ])

    const [validBet2, validBetError2] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError2).toBeNull()
    expect(validBet2).toBe(`20.00000000`)

    let expectMoves = []
    for (let i = 0; i < joeMoves.length; i++) {
      let joeMove = joeMoves[i]
      expectMoves.push({
        color: {
          rawValue: StoneColor.black
        },
        location: {
          x: joeMove.x,
          y: joeMove.y
        }
      })
      let bobMove = bobMoves[i]
      if (bobMove) {
        expectMoves.push({
          color: {
            rawValue: StoneColor.white
          },
          location: {
            x: bobMove.x,
            y: bobMove.y
          }
        })
      }
    }
    expectMoves.push(
    {
      color: {
        rawValue: StoneColor.white
      },
      location: {
        x: 11,
        y: 7
      }
    })

    // bob's Move
    await makeMove(bob, compositionIndex, roundIndex, {
      color: StoneColor.white,
      x: 11,
      y: 7
    }, 1, expectMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    console.log(scriptResult2)
    expect(scriptResult2).toEqual({
      rawValue: Result.challengerWins
    })

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    console.log(aliceBalance)
    expect(aliceBalance).toEqual("1.00100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError).toBeNull()
    console.log(joeBalance)
    expect(joeBalance).toEqual("11.20100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    console.log(bobBalance)
    expect(bobBalance).toEqual("28.80100000")

  }, 5 * 60 * 1000)

  test("challenger wins with raise bet", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)
    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
    let roundIndex = 0

    let bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 1
      },
      {
        x: 8,
        y: 7,
        raiseBet: 1
      },
      {
        x: 9,
        y: 7,
        raiseBet: 1
      },
      {
        x: 10,
        y: 7,
        raiseBet: 1
      },
      {
        x: 11,
        y: 7,
        raiseBet: 1
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 0
      },
      {
        x: 8,
        y: 8,
        raiseBet: 0
      },
      {
        x: 9,
        y: 8,
        raiseBet: 0
      },
      {
        x: 10,
        y: 8,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets, hostBetsError] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError).toBeNull()
    expect(hostBets).toEqual([
      '10.00000000',
      '0.00000000'
    ])

    const [challengerBets, challengerBetsError] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError).toBeNull()
    expect(challengerBets).toEqual([
      '10.00000000',
      '5.00000000'
    ])

    const [validBet, validBetError] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError).toBeNull()
    expect(validBet).toBe(`20.00000000`)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult).toEqual({
      rawValue: Result.challengerWins
    })

    roundIndex++

    joeMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 0
      },
      {
        x: 8,
        y: 8,
        raiseBet: 0
      },
      {
        x: 9,
        y: 8,
        raiseBet: 0
      },
      {
        x: 10,
        y: 8,
        raiseBet: 0
      },
      {
        x: 10,
        y: 9,
        raiseBet: 2
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 0
      },
      {
        x: 8,
        y: 7,
        raiseBet: 0
      },
      {
        x: 9,
        y: 7,
        raiseBet: 0
      },
      {
        x: 10,
        y: 7,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets2, hostBetsError2] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError2).toBeNull()
    expect(hostBets2).toEqual([
      '10.00000000',
      '2.00000000'
    ])

    const [challengerBets2, challengerBetsError2] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError2).toBeNull()
    expect(challengerBets2).toEqual([
      '10.00000000',
      '5.00000000'
    ])

    const [validBet2, validBetError2] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError2).toBeNull()
    expect(validBet2).toBe(`24.00000000`)

    let expectMoves = []
    for (let i = 0; i < joeMoves.length; i++) {
      let joeMove = joeMoves[i]
      expectMoves.push({
        color: {
          rawValue: StoneColor.black
        },
        location: {
          x: joeMove.x,
          y: joeMove.y
        }
      })
      let bobMove = bobMoves[i]
      if (bobMove) {
        expectMoves.push({
          color: {
            rawValue: StoneColor.white
          },
          location: {
            x: bobMove.x,
            y: bobMove.y
          }
        })
      }
    }
    expectMoves.push(
    {
      color: {
        rawValue: StoneColor.white
      },
      location: {
        x: 11,
        y: 7
      }
    })

    // bob's Move
    await makeMove(bob, compositionIndex, roundIndex, {
      color: StoneColor.white,
      x: 11,
      y: 7
    }, 1, expectMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    console.log(scriptResult2)
    expect(scriptResult2).toEqual({
      rawValue: Result.challengerWins
    })

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    console.log(aliceBalance)
    expect(aliceBalance).toEqual("1.20100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError).toBeNull()
    console.log(joeBalance)
    expect(joeBalance).toEqual("9.24100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError).toBeNull()
    console.log(bobBalance)
    expect(bobBalance).toEqual("30.56100000")

  }, 5 * 60 * 1000)

  test("host wins without matched raise bet", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)

    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
    let roundIndex = 0

    let bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 0
      },
      {
        x: 8,
        y: 7,
        raiseBet: 0
      },
      {
        x: 9,
        y: 7,
        raiseBet: 0
      },
      {
        x: 10,
        y: 7,
        raiseBet: 0
      },
      {
        x: 11,
        y: 6,
        raiseBet: 5
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 0
      },
      {
        x: 8,
        y: 9,
        raiseBet: 0
      },
      {
        x: 9,
        y: 10,
        raiseBet: 0
      },
      {
        x: 10,
        y: 11,
        raiseBet: 0
      },
      {
        x: 11,
        y: 12,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets, hostBetsError] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError).toBeNull()
    expect(hostBets).toEqual([
      '10.00000000',
      '0.00000000'
    ])

    const [challengerBets, challengerBetsError] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError).toBeNull()
    expect(challengerBets).toEqual([
      '10.00000000',
      '5.00000000'
    ])

    const [validBet, validBetError] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError).toBeNull()
    expect(validBet).toBe(`20.00000000`)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult).toEqual({
      rawValue: Result.hostWins
    })

    roundIndex++

    joeMoves = [
      {
        x: 8,
        y: 7,
        raiseBet: 0
      },
      {
        x: 7,
        y: 6,
        raiseBet: 0
      },
      {
        x: 6,
        y: 5,
        raiseBet: 0
      },
      {
        x: 5,
        y: 4,
        raiseBet: 0
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 0
      },
      {
        x: 4,
        y: 7,
        raiseBet: 0
      },
      {
        x: 9,
        y: 7,
        raiseBet: 0
      },
      {
        x: 10,
        y: 7,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets2, hostBetsError2] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError2).toBeNull()
    expect(hostBets2).toEqual([
      '10.00000000',
      '0.00000000'
    ])

    const [challengerBets2, challengerBetsError2] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError2).toBeNull()
    expect(challengerBets2).toEqual([
      '10.00000000',
      '5.00000000'
    ])

    const [validBet2, validBetError2] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError2).toBeNull()
    expect(validBet2).toBe(`20.00000000`)

    let expectMoves = []
    for (let i = 0; i < joeMoves.length; i++) {
      let joeMove = joeMoves[i]
      expectMoves.push({
        color: {
          rawValue: StoneColor.black
        },
        location: {
          x: joeMove.x,
          y: joeMove.y
        }
      })
      let bobMove = bobMoves[i]
      if (bobMove) {
        expectMoves.push({
          color: {
            rawValue: StoneColor.white
          },
          location: {
            x: bobMove.x,
            y: bobMove.y
          }
        })
      }
    }
    expectMoves.push(
    {
      color: {
        rawValue: StoneColor.black
      },
      location: {
        x: 4,
        y: 3
      }
    })

    // joe's Move
    await makeMove(joe, compositionIndex, roundIndex, {
      color: StoneColor.white,
      x: 4,
      y: 3
    }, 0, expectMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    console.log(scriptResult2)
    expect(scriptResult2).toEqual({
      rawValue: Result.hostWins
    })

    const [aliceBalance2, aliceBalanceError2] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError2).toBeNull()
    console.log(aliceBalance2)
    expect(aliceBalance2).toEqual("1.00100000")

    const [joeBalance2, joeBalanceError2] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError2).toBeNull()
    console.log(joeBalance2)
    expect(joeBalance2).toEqual("30.00100000")

    const [bobBalance2, bobBalanceError2] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError2).toBeNull()
    console.log(bobBalance2)
    expect(bobBalance2).toEqual("10.00100000")

  }, 5 * 60 * 1000)

  test("host wins with raise bet", async () => {
    const joe = await getAccountAddress(joeAddressName)
    const bob = await getAccountAddress(bobAddressName)

    const alice = await getAccountAddress(adminAddressName)

    const compositionIndex = 0
    let roundIndex = 0

    let bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 0
      },
      {
        x: 8,
        y: 7,
        raiseBet: 0
      },
      {
        x: 9,
        y: 7,
        raiseBet: 0
      },
      {
        x: 10,
        y: 7,
        raiseBet: 0
      },
      {
        x: 11,
        y: 6,
        raiseBet: 5
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 0
      },
      {
        x: 8,
        y: 9,
        raiseBet: 0
      },
      {
        x: 9,
        y: 10,
        raiseBet: 0
      },
      {
        x: 10,
        y: 11,
        raiseBet: 0
      },
      {
        x: 11,
        y: 12,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets, hostBetsError] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError).toBeNull()
    expect(hostBets).toEqual([
      '10.00000000',
      '0.00000000'
    ])

    const [challengerBets, challengerBetsError] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError).toBeNull()
    expect(challengerBets).toEqual([
      '10.00000000',
      '5.00000000'
    ])

    const [validBet, validBetError] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError).toBeNull()
    expect(validBet).toBe(`20.00000000`)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult).toEqual({
      rawValue: Result.hostWins
    })

    roundIndex++

    joeMoves = [
      {
        x: 8,
        y: 7,
        raiseBet: 0
      },
      {
        x: 7,
        y: 6,
        raiseBet: 0
      },
      {
        x: 6,
        y: 5,
        raiseBet: 0
      },
      {
        x: 5,
        y: 4,
        raiseBet: 0
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 0
      },
      {
        x: 4,
        y: 7,
        raiseBet: 0
      },
      {
        x: 9,
        y: 7,
        raiseBet: 0
      },
      {
        x: 10,
        y: 7,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets2, hostBetsError2] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError2).toBeNull()
    expect(hostBets2).toEqual([
      '10.00000000',
      '0.00000000'
    ])

    const [challengerBets2, challengerBetsError2] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError2).toBeNull()
    expect(challengerBets2).toEqual([
      '10.00000000',
      '5.00000000'
    ])

    const [validBet2, validBetError2] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError2).toBeNull()
    expect(validBet2).toBe(`20.00000000`)

    let expectMoves = []
    for (let i = 0; i < joeMoves.length; i++) {
      let joeMove = joeMoves[i]
      expectMoves.push({
        color: {
          rawValue: StoneColor.black
        },
        location: {
          x: joeMove.x,
          y: joeMove.y
        }
      })
      let bobMove = bobMoves[i]
      if (bobMove) {
        expectMoves.push({
          color: {
            rawValue: StoneColor.white
          },
          location: {
            x: bobMove.x,
            y: bobMove.y
          }
        })
      }
    }
    expectMoves.push(
    {
      color: {
        rawValue: StoneColor.black
      },
      location: {
        x: 4,
        y: 3
      }
    })

    // joe's Move
    await makeMove(joe, compositionIndex, roundIndex, {
      color: StoneColor.white,
      x: 4,
      y: 3
    }, 5, expectMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    console.log(scriptResult2)
    expect(scriptResult2).toEqual({
      rawValue: Result.hostWins
    })

    const [aliceBalance2, aliceBalanceError2] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError2).toBeNull()
    console.log(aliceBalance2)
    expect(aliceBalance2).toEqual("1.50100000")

    const [joeBalance2, joeBalanceError2] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError2).toBeNull()
    console.log(joeBalance2)
    expect(joeBalance2).toEqual("34.50100000")

    const [bobBalance2, bobBalanceError2] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError2).toBeNull()
    console.log(bobBalance2)
    expect(bobBalance2).toEqual("5.00100000")

  }, 5 * 60 * 1000)

  test("draw", async () => {

    const compositionIndex = 0
    let roundIndex = 0

    let bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 2
      },
      {
        x: 8,
        y: 7,
        raiseBet: 2
      },
      {
        x: 9,
        y: 7,
        raiseBet: 0
      },
      {
        x: 10,
        y: 7,
        raiseBet: 0
      },
      {
        x: 11,
        y: 7,
        raiseBet: 0
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 2
      },
      {
        x: 8,
        y: 8,
        raiseBet: 2
      },
      {
        x: 9,
        y: 8,
        raiseBet: 2
      },
      {
        x: 10,
        y: 8,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets, hostBetsError] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError).toBeNull()
    expect(hostBets).toEqual([
      '10.00000000',
      '6.00000000'
    ])

    const [challengerBets, challengerBetsError] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError).toBeNull()
    expect(challengerBets).toEqual([
      '10.00000000',
      '4.00000000'
    ])

    const [validBet, validBetError] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError).toBeNull()
    expect(validBet).toBe(`28.00000000`)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult).toEqual({
      rawValue: Result.challengerWins
    })

    roundIndex++

    joeMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 0
      },
      {
        x: 8,
        y: 7,
        raiseBet: 1
      },
      {
        x: 9,
        y: 7,
        raiseBet: 1
      },
      {
        x: 10,
        y: 7,
        raiseBet: 1
      },
      {
        x: 11,
        y: 7,
        raiseBet: 1
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 0
      },
      {
        x: 8,
        y: 8,
        raiseBet: 0
      },
      {
        x: 9,
        y: 8,
        raiseBet: 0
      },
      {
        x: 10,
        y: 8,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    console.log(scriptResult2)
    expect(scriptResult2).toEqual({
      rawValue: Result.hostWins
    })

    const alice = await getAccountAddress(adminAddressName)
    const [aliceBalance2, aliceBalanceError2] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError2).toBeNull()
    console.log(aliceBalance2)
    expect(aliceBalance2).toEqual("0.56100000")

    const joe = await getAccountAddress(joeAddressName)
    const [joeBalance2, joeBalanceError2] = await executeScript('Flow-balance', [joe])
    expect(joeBalanceError2).toBeNull()
    console.log(joeBalance2)
    expect(joeBalance2).toEqual("20.72100000")

    const bob = await getAccountAddress(bobAddressName)
    const [bobBalance2, bobBalanceError2] = await executeScript('Flow-balance', [bob])
    expect(bobBalanceError2).toBeNull()
    console.log(bobBalance2)
    expect(bobBalance2).toEqual("19.72100000")

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
        y: 7,
        raiseBet: 1
      },
      {
        x: 8,
        y: 7,
        raiseBet: 1
      },
      {
        x: 9,
        y: 7,
        raiseBet: 1
      },
      {
        x: 10,
        y: 7,
        raiseBet: 1
      }
    ]

    let joeMoves = [
      {
        x: 7,
        y: 8,
        raiseBet: 1
      },
      {
        x: 8,
        y: 9,
        raiseBet: 1
      },
      {
        x: 9,
        y: 10,
        raiseBet: 1
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [hostBets, hostBetsError] = await executeScript('Gomoku-get-host-bet', [compositionIndex])
    expect(hostBetsError).toBeNull()
    expect(hostBets).toEqual([
      '10.00000000',
      '3.00000000'
    ])

    const [challengerBets, challengerBetsError] = await executeScript('Gomoku-get-challenger-bet', [compositionIndex])
    expect(challengerBetsError).toBeNull()
    expect(challengerBets).toEqual([
      '10.00000000',
      '4.00000000'
    ])

    const [validBet, validBetError] = await executeScript('Gomoku-get-valid-bets', [compositionIndex])
    expect(validBetError).toBeNull()
    expect(validBet).toBe(`26.00000000`)

    const [scriptResult, scriptError] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError).toBeNull()
    console.log(scriptResult)
    expect(scriptResult).toBeNull()

    const signers = [joe]
    const args = [compositionIndex]

    const [txResult, error] = await shallPass(
      sendTransaction('Gomoku-surrender', signers, args)
    )
    expect(error).toBeNull()
    console.log(txResult, error)

    roundIndex++

    joeMoves = [
      {
        x: 8,
        y: 7,
        raiseBet: 1
      },
      {
        x: 7,
        y: 6,
        raiseBet: 0
      },
      {
        x: 6,
        y: 5,
        raiseBet: 0
      },
      {
        x: 5,
        y: 4,
        raiseBet: 0
      }
    ]

    bobMoves = [
      {
        x: 7,
        y: 7,
        raiseBet: 1
      },
      {
        x: 4,
        y: 7,
        raiseBet: 0
      },
      {
        x: 9,
        y: 7,
        raiseBet: 0
      }
    ]

    await simulateMovesWithRaise(compositionIndex, roundIndex, joeAddressName, bobAddressName, joeMoves, bobMoves)

    const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-round-winner', [compositionIndex, roundIndex])
    expect(scriptError2).toBeNull()
    console.log(scriptResult2)
    expect(scriptResult2).toBeNull()

    const signers2 = [joe]
    const args2 = [compositionIndex]

    const [txResult2, error2] = await shallPass(
      sendTransaction('Gomoku-surrender', signers2, args2)
    )
    expect(error2).toBeNull()
    console.log(txResult2, error2)

    const [aliceBalance, aliceBalanceError] = await executeScript('Flow-balance', [alice])
    expect(aliceBalanceError).toBeNull()
    console.log(aliceBalance)
    expect(aliceBalance).toEqual("1.40100000")

    const [joeBalance, joeBalanceError] = await executeScript('Flow-balance', [joe])
    console.log(joeBalance)
    expect(joeBalanceError).toBeNull()
    expect(joeBalance).toEqual("7.28100000")

    const [bobBalance, bobBalanceError] = await executeScript('Flow-balance', [bob])
    console.log(bobBalance)
    expect(bobBalanceError).toBeNull()
    expect(bobBalance).toEqual("32.32100000")

  }, 5 * 60 * 1000)

})