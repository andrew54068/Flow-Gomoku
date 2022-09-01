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

export const Role = {
  host: 0,
  challenger: 1
}

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

export const matchGomokuAlongWithRegister = async (hostAddressName, bet) => {
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

export const simulateMoves = async (compositionIndex, roundIndex, host, bobMoves, aliceMoves) => {
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