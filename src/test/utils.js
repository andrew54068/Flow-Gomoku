import {
  getAccountAddress,
  deployContractByName,
  executeScript,
  sendTransaction,
  shallPass
} from "@onflow/flow-js-testing";

export const StoneColor = {
  black: 0,
  white: 1
}

export const Result = {
  hostWins: 0,
  challengerWins: 1,
  draw: 2
}

export const roundDrawSteps = [
  { x: 0, y: 0 }, { x: 1, y: 0 }, { x: 4, y: 0 }, { x: 5, y: 0 },
  { x: 8, y: 0 }, { x: 9, y: 0 }, { x: 12, y: 0 }, { x: 13, y: 0 },
  { x: 2, y: 1 }, { x: 3, y: 1 }, { x: 6, y: 1 }, { x: 7, y: 1 },
  { x: 10, y: 1 }, { x: 11, y: 1 }, { x: 14, y: 1 }, { x: 0, y: 2 },
  { x: 1, y: 2 }, { x: 4, y: 2 }, { x: 5, y: 2 }, { x: 8, y: 2 },
  { x: 9, y: 2 }, { x: 12, y: 2 }, { x: 13, y: 2 }, { x: 2, y: 3 },
  { x: 3, y: 3 }, { x: 6, y: 3 }, { x: 7, y: 3 }, { x: 10, y: 3 },
  { x: 11, y: 3 }, { x: 14, y: 3 }, { x: 0, y: 4 }, { x: 1, y: 4 },
  { x: 4, y: 4 }, { x: 5, y: 4 }, { x: 8, y: 4 }, { x: 9, y: 4 },
  { x: 12, y: 4 }, { x: 13, y: 4 }, { x: 2, y: 5 }, { x: 3, y: 5 },
  { x: 6, y: 5 }, { x: 7, y: 5 }, { x: 10, y: 5 }, { x: 11, y: 5 },
  { x: 14, y: 5 }, { x: 0, y: 6 }, { x: 1, y: 6 }, { x: 4, y: 6 },
  { x: 5, y: 6 }, { x: 8, y: 6 }, { x: 9, y: 6 }, { x: 12, y: 6 },
  { x: 13, y: 6 }, { x: 2, y: 7 }, { x: 3, y: 7 }, { x: 6, y: 7 },
  { x: 7, y: 7 }, { x: 10, y: 7 }, { x: 11, y: 7 }, { x: 14, y: 7 },
  { x: 0, y: 8 }, { x: 1, y: 8 }, { x: 4, y: 8 }, { x: 5, y: 8 },
  { x: 8, y: 8 }, { x: 9, y: 8 }, { x: 12, y: 8 }, { x: 13, y: 8 },
  { x: 2, y: 9 }, { x: 3, y: 9 }, { x: 6, y: 9 }, { x: 7, y: 9 },
  { x: 10, y: 9 }, { x: 11, y: 9 }, { x: 14, y: 9 }, { x: 0, y: 10 },
  { x: 1, y: 10 }, { x: 4, y: 10 }, { x: 5, y: 10 }, { x: 8, y: 10 },
  { x: 9, y: 10 }, { x: 12, y: 10 }, { x: 13, y: 10 }, { x: 2, y: 11 },
  { x: 3, y: 11 }, { x: 6, y: 11 }, { x: 7, y: 11 }, { x: 10, y: 11 },
  { x: 11, y: 11 }, { x: 14, y: 11 }, { x: 0, y: 12 }, { x: 1, y: 12 },
  { x: 4, y: 12 }, { x: 5, y: 12 }, { x: 8, y: 12 }, { x: 9, y: 12 },
  { x: 12, y: 12 }, { x: 13, y: 12 }, { x: 2, y: 13 }, { x: 3, y: 13 },
  { x: 6, y: 13 }, { x: 7, y: 13 }, { x: 10, y: 13 }, { x: 11, y: 13 },
  { x: 14, y: 13 }, { x: 0, y: 14 }, { x: 1, y: 14 }, { x: 4, y: 14 },
  { x: 5, y: 14 }, { x: 8, y: 14 }, { x: 9, y: 14 }, { x: 12, y: 14 },
  { x: 13, y: 14 }
]

export const roundDrawSteps2 = [
  { x: 2, y: 0 }, { x: 3, y: 0 }, { x: 6, y: 0 }, { x: 7, y: 0 },
  { x: 10, y: 0 }, { x: 11, y: 0 }, { x: 14, y: 0 }, { x: 0, y: 1 },
  { x: 1, y: 1 }, { x: 4, y: 1 }, { x: 5, y: 1 }, { x: 8, y: 1 },
  { x: 9, y: 1 }, { x: 12, y: 1 }, { x: 13, y: 1 }, { x: 2, y: 2 },
  { x: 3, y: 2 }, { x: 6, y: 2 }, { x: 7, y: 2 }, { x: 10, y: 2 },
  { x: 11, y: 2 }, { x: 14, y: 2 }, { x: 0, y: 3 }, { x: 1, y: 3 },
  { x: 4, y: 3 }, { x: 5, y: 3 }, { x: 8, y: 3 }, { x: 9, y: 3 },
  { x: 12, y: 3 }, { x: 13, y: 3 }, { x: 2, y: 4 }, { x: 3, y: 4 },
  { x: 6, y: 4 }, { x: 7, y: 4 }, { x: 10, y: 4 }, { x: 11, y: 4 },
  { x: 14, y: 4 }, { x: 0, y: 5 }, { x: 1, y: 5 }, { x: 4, y: 5 },
  { x: 5, y: 5 }, { x: 8, y: 5 }, { x: 9, y: 5 }, { x: 12, y: 5 },
  { x: 13, y: 5 }, { x: 2, y: 6 }, { x: 3, y: 6 }, { x: 6, y: 6 },
  { x: 7, y: 6 }, { x: 10, y: 6 }, { x: 11, y: 6 }, { x: 14, y: 6 },
  { x: 0, y: 7 }, { x: 1, y: 7 }, { x: 4, y: 7 }, { x: 5, y: 7 },
  { x: 8, y: 7 }, { x: 9, y: 7 }, { x: 12, y: 7 }, { x: 13, y: 7 },
  { x: 2, y: 8 }, { x: 3, y: 8 }, { x: 6, y: 8 }, { x: 7, y: 8 },
  { x: 10, y: 8 }, { x: 11, y: 8 }, { x: 14, y: 8 }, { x: 0, y: 9 },
  { x: 1, y: 9 }, { x: 4, y: 9 }, { x: 5, y: 9 }, { x: 8, y: 9 },
  { x: 9, y: 9 }, { x: 12, y: 9 }, { x: 13, y: 9 }, { x: 2, y: 10 },
  { x: 3, y: 10 }, { x: 6, y: 10 }, { x: 7, y: 10 }, { x: 10, y: 10 },
  { x: 11, y: 10 }, { x: 14, y: 10 }, { x: 0, y: 11 }, { x: 1, y: 11 },
  { x: 4, y: 11 }, { x: 5, y: 11 }, { x: 8, y: 11 }, { x: 9, y: 11 },
  { x: 12, y: 11 }, { x: 13, y: 11 }, { x: 2, y: 12 }, { x: 3, y: 12 },
  { x: 6, y: 12 }, { x: 7, y: 12 }, { x: 10, y: 12 }, { x: 11, y: 12 },
  { x: 14, y: 12 }, { x: 0, y: 13 }, { x: 1, y: 13 }, { x: 4, y: 13 },
  { x: 5, y: 13 }, { x: 8, y: 13 }, { x: 9, y: 13 }, { x: 12, y: 13 },
  { x: 13, y: 13 }, { x: 2, y: 14 }, { x: 3, y: 14 }, { x: 6, y: 14 },
  { x: 7, y: 14 }, { x: 10, y: 14 }, { x: 11, y: 14 }, { x: 14, y: 14 }
]

export const adminAddressName = "Alice"

export const expectContractDeployed = (deploymentResult, name) => {
  expect(deploymentResult.statusString).toBe('SEALED')
  let event = deploymentResult.events.filter(value => value.type == 'flow.AccountContractAdded')
  expect(event.length).toBe(1)
}

export const deployMatcher = async () => {
  const to = await getAccountAddress("Alice")

  // We assume there is a file on "../cadence/contracts/MatchContract.cdc" path
  const name = "MatchContract"

  const [deploymentResult, error] = await deployContractByName({ to, name })
  expect(error).toBeNull()
  expect(deploymentResult.statusString).toBe('SEALED')
  let event = deploymentResult.events.filter(value => value.type == 'flow.AccountContractAdded')
  expect(event.length).toBe(1)
  expectContractDeployed(deploymentResult, name)
}

export const deployGomokuType = async () => {
  const to = await getAccountAddress("Alice")

  // We assume there is a file on "../cadence/contracts/GomokuType.cdc" path
  const name = "GomokuType"

  const [deploymentResult, error] = await deployContractByName({ to, name })
  expect(error).toBeNull()
  expect(deploymentResult.statusString).toBe('SEALED')
  let event = deploymentResult.events.filter(value => value.type == 'flow.AccountContractAdded')
  expect(event.length).toBe(1)
  expectContractDeployed(deploymentResult, name)
}

export const deployContract = async (name) => {
  const to = await getAccountAddress("Alice")

  const [deploymentResult, error] = await deployContractByName({ to, name })
  expect(error).toBeNull()
  expect(deploymentResult.statusString).toBe('SEALED')
  let event = deploymentResult.events.filter(value => value.type == 'flow.AccountContractAdded')
  expect(event.length).toBe(1)
  expectContractDeployed(deploymentResult, name)
}

export const serviceAccountMintTo = async (receiver, amount) => {
  const serviceAccount = ['0xf8d6e0586b0a20c7']
  const mintArgs = [receiver, amount]

  const [mintResult, mintError] = await shallPass(
    sendTransaction('Mint-flow', serviceAccount, mintArgs)
  )
  expect(mintError).toBeNull()
  console.log(mintResult)
}

export const registerWithFlowByAddress = async (addressName, bet) => {

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

export const matching = async (challenger, budget) => {
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

export const matchGomokuAlongWithRegister = async (index, hostAddressName, challengerAddressName, bet) => {
  await registerWithFlowByAddress(hostAddressName, bet)

  const host = await getAccountAddress(hostAddressName)

  const challenger = await getAccountAddress(challengerAddressName)

  await matching(challenger, bet)

  const [scriptResult, scriptError] = await executeScript('Gomoku-get-composition-ref', [index])
  expect(scriptError).toBeNull()
  console.log(scriptResult)
  expect(scriptResult["host"]).toBe(host)
  expect(scriptResult["challenger"]).toBe(challenger)
  expect(scriptResult["currentRound"]).toBe(0)
  expect(scriptResult["id"]).toBe(index)
  expect(Object.keys(scriptResult["locationStoneMaps"]).length).toBe(2)
  expect(scriptResult["roundWinners"]).toEqual([])
  expect(scriptResult["steps"]).toEqual([[], []])
  expect(scriptResult["totalRound"]).toBe(2)
  expect(scriptResult["winner"]).toBeNull()

  const [scriptResult2, scriptError2] = await executeScript('Gomoku-get-participants', [index])
  expect(scriptError2).toBeNull()
  expect(scriptResult2).toEqual([host, challenger])

  const [scriptResult3, scriptError3] = await executeScript('Gomoku-get-opening-bet', [index])
  expect(scriptError3).toBeNull()
  expect(scriptResult3).toBe(`${bet * 2}.00000000`)

  const [scriptResult4, scriptError4] = await executeScript('Gomoku-get-valid-bets', [index])
  expect(scriptError4).toBeNull()
  expect(scriptResult4).toBe(`${bet * 2}.00000000`)
}

export const makeMove = async (player, index, round, stone, raiseBet, expectStoneData) => {
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

export const simulateMoves = async (
  compositionIndex,
  roundIndex,
  hostName,
  challengerName,
  hostMoves,
  challengerMoves
) => {
  const host = await getAccountAddress(hostName)
  const challenger = await getAccountAddress(challengerName)
  let firstTaker
  let secondTaker
  let firstTakerMoves = []
  let secondTakerMoves = []
  if (roundIndex % 2 == 0) {
    firstTaker = challenger
    secondTaker = host
    firstTakerMoves = challengerMoves
    secondTakerMoves = hostMoves
  } else {
    firstTaker = host
    secondTaker = challenger
    firstTakerMoves = hostMoves
    secondTakerMoves = challengerMoves
  }
  let moves = []
  for (let step = 0; step < firstTakerMoves.length; step++) {
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

export const simulateMovesWithRaise = async (
  compositionIndex,
  roundIndex,
  hostName,
  challengerName,
  hostMovesWithRaise,
  challengerMovesWithRaise
) => {
  const host = await getAccountAddress(hostName)
  const challenger = await getAccountAddress(challengerName)
  let firstTaker
  let secondTaker
  let firstTakerMoves = []
  let secondTakerMoves = []
  if (roundIndex % 2 == 0) {
    firstTaker = challenger
    secondTaker = host
    firstTakerMoves = challengerMovesWithRaise
    secondTakerMoves = hostMovesWithRaise
  } else {
    firstTaker = host
    secondTaker = challenger
    firstTakerMoves = hostMovesWithRaise
    secondTakerMoves = challengerMovesWithRaise
  }
  let expectMoves = []
  for (let step = 0; step < firstTakerMoves.length; step++) {
    const firstTakerMove = firstTakerMoves[step]
    if (firstTakerMove) {
      expectMoves.push(
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
      }, firstTakerMove.raiseBet, expectMoves)
    }
    const secondTakerMove = secondTakerMoves[step]
    if (secondTakerMove) {
      expectMoves.push(
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
      }, secondTakerMove.raiseBet, expectMoves)
    }
  }
}