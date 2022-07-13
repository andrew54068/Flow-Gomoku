import path from "path";
import {
  emulator,
  init,
  getAccountAddress,
  executeScript,
  sendTransaction,
  shallPass,
  shallRevert
} from "@onflow/flow-js-testing";
import { deployMatcher, expectContractDeployed } from "./utils";

describe("Matcher", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../cadence");

    await init(basePath)
    await emulator.start({
      logging: false,
    })

    await deployMatcher()
  });

  //  Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  })

  test("match successfully", async () => {

    emulator.setLogging(true)

    const alice = await getAccountAddress("Alice")
    const args = []
    const signers = [alice]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

    const [activeMatchTxResult, activeMatchError] = await shallPass(
      sendTransaction('TestMatcher-admin-active-match', [alice], [])
    )
    console.log(activeMatchTxResult, activeMatchError)
    expect(activeMatchError).toBeNull()

    const [scriptResult, scriptError] = await executeScript('Matcher-get-random-waiting-index', [])
    expect(scriptError).toBeNull()
    expect(scriptResult).toBe(0)

    const bob = await getAccountAddress("Bob")
    const args2 = [scriptResult]
    const signers2 = [bob]

    const [txResult2, error2] = await shallPass(
      sendTransaction('TestMatcher-match', signers2, args2)
    )
    console.log(txResult2, error2)

    const [hostResult, hostScriptError] = await executeScript('Matcher-get-host-by-index', [0])
    expect(hostScriptError).toBeNull()
    expect(hostResult).toEqual(alice)

    const [challengerResult, challengerScriptError] = await executeScript('Matcher-get-challenger-by-index', [0])
    expect(challengerScriptError).toBeNull()
    expect(challengerResult).toEqual(bob)

    const [scriptResult2, scriptError2] = await executeScript('Matcher-get-random-waiting-index', [])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toBeNull()

    const [aliceWaitingIndex, aliceWaitingError] = await executeScript('Matcher-get-first-waiting-index-by-address', [alice])
    expect(aliceWaitingError).toBeNull()
    expect(aliceWaitingIndex).toBeNull()
    
    const [aliceMatchedIndex, aliceMatchedError] = await executeScript('Matcher-get-matched-by-address', [alice])
    expect(aliceMatchedError).toBeNull()
    expect(aliceMatchedIndex).toEqual([0])

    const [aliceWaitingInde2, aliceWaitingError2] = await executeScript('Matcher-get-waiting-by-address', [alice])
    expect(aliceWaitingError2).toBeNull()
    expect(aliceWaitingInde2).toEqual([])
    
    const [bobWaitingIndex, bobWaitingError] = await executeScript('Matcher-get-first-waiting-index-by-address', [bob])
    expect(bobWaitingError).toBeNull()
    expect(bobWaitingIndex).toBeNull()

    const [bobWaitingIndex2, bobWaitingError2] = await executeScript('Matcher-get-waiting-by-address', [bob])
    expect(bobWaitingError2).toBeNull()
    expect(bobWaitingIndex2).toEqual([])

    const [bobMatchedIndex, bobMatchedError] = await executeScript('Matcher-get-matched-by-address', [bob])
    expect(bobMatchedError).toBeNull()
    expect(bobMatchedIndex).toEqual([0])

    const [waitingIndices, waitingIndicesError] = await executeScript('Matcher-get-waiting-indices', [])
    expect(waitingIndicesError).toBeNull()
    expect(waitingIndices).toEqual([])
    
    const [matchIndices, matchIndicesError] = await executeScript('Matcher-get-matched-indices', [])
    expect(matchIndicesError).toBeNull()
    expect(matchIndices).toEqual([0])

    const args3 = []
    const signers3 = [bob]

    const [txResult3, error3] = await shallRevert(
      sendTransaction('TestMatcher-modify-by-other', signers3, args3)
    )
    console.log(txResult3, error3)

    const [hostResult2, hostScriptError2] = await executeScript('Matcher-get-host-by-index', [0])
    expect(hostScriptError2).toBeNull()
    expect(hostResult2).toEqual(alice)

    emulator.setLogging(false)

  })
})