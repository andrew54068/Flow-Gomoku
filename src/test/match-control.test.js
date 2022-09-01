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
import { deployMatcher } from "./utils";

describe("Matcher control", () => {
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

  test("Register not active", async () => {

    const to = await getAccountAddress("Alice")
    const args = []
    const signers = [to]

    const [txResult, error] = await shallRevert(
      sendTransaction('TestMatcher-init', signers, args)
    )
    console.log(txResult, error)

  })

  test("Register active", async () => {

    const to = await getAccountAddress("Alice")
    const args = []
    const signers = [to]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

  })

  test("Register active by other", async () => {

    const to = await getAccountAddress("Bob")
    const args = []
    const signers = [to]

    const [txResult, error] = await shallRevert(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

  })

  test("Register inactive", async () => {

    const to = await getAccountAddress("Alice")
    const args = []
    const signers = [to]

    const [txResult, error] = await shallRevert(
      sendTransaction('TestMatcher-admin-inactive-register', signers, args)
    )
    console.log(txResult, error)

  })

  test("Register active register by other", async () => {

    const to = await getAccountAddress("Alice")
    const args = []
    const signers = [to]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

    const bob = await getAccountAddress("Bob")
    const args2 = []
    const signers2 = [bob]

    const [txResult2, error2] = await shallPass(
      sendTransaction('TestMatcher-register', signers2, args2)
    )
    console.log(txResult2, error2)

  })

  test("next index increase", async () => {

    const [result, scriptError] = await executeScript('Matcher-get-index', [])
    expect(scriptError).toBeNull()
    expect(result).toBe(0)

    const to = await getAccountAddress("Alice")
    const args = []
    const signers = [to]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

    const [registerTxResult, registerError] = await shallPass(
      sendTransaction('TestMatcher-register', signers, args)
    )
    console.log(registerTxResult, registerError)

    const [result2, scriptError2] = await executeScript('Matcher-get-index', [])
    expect(scriptError2).toBeNull()
    expect(result2).toBe(1)

    const bob = await getAccountAddress("Bob")
    const args2 = []
    const signers2 = [bob]

    const [txResult2, error2] = await shallPass(
      sendTransaction('TestMatcher-register', signers2, args2)
    )
    console.log(txResult2, error2)

    const [result3, scriptError3] = await executeScript('Matcher-get-index', [])
    expect(scriptError3).toBeNull()
    expect(result3).toBe(2)
  })

  test("next index not increase", async () => {

    const [result, scriptError] = await executeScript('Matcher-get-index', [])
    expect(scriptError).toBeNull()
    expect(result).toBe(0)

    const bob = await getAccountAddress("Bob")
    const args2 = []
    const signers2 = [bob]

    const [txResult2, error2] = await shallRevert(
      sendTransaction('TestMatcher-register', signers2, args2)
    )
    console.log(txResult2, error2)

    const [result2, scriptError2] = await executeScript('Matcher-get-index', [])
    expect(scriptError2).toBeNull()
    expect(result2).toBe(0)
  })

  test("get index by address before and after register", async () => {

    const [scriptResult, scriptError] = await executeScript('Matcher-get-random-waiting-index', [])
    expect(scriptError).toBeNull()
    expect(scriptResult).toBeNull()

    const alice = await getAccountAddress("Alice")
    const args = []
    const signers = [alice]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

    const [registerTxResult, registerError] = await shallPass(
      sendTransaction('TestMatcher-register', signers, args)
    )
    console.log(registerTxResult, registerError)

    const bob = await getAccountAddress("Bob")
    const args2 = []
    const signers2 = [bob]

    const [txResult2, error2] = await shallPass(
      sendTransaction('TestMatcher-register', signers2, args2)
    )
    console.log(txResult2, error2)

    const [scriptResult2, scriptError2] = await executeScript('Matcher-get-random-waiting-index', [])
    expect(scriptError2).toBeNull()
    expect(scriptResult2).toBe(0)

    const [aliceWaitingIndex, scriptError3] = await executeScript('Matcher-get-first-waiting-index-by-address', [alice])
    expect(scriptError3).toBeNull()
    expect(aliceWaitingIndex).toBe(0)

    const [bobWaitingIndex, scriptError4] = await executeScript('Matcher-get-first-waiting-index-by-address', [bob])
    expect(scriptError4).toBeNull()
    expect(bobWaitingIndex).toBe(1)

  })

  test("match not active", async () => {

    const alice = await getAccountAddress("Alice")
    const args = []
    const signers = [alice]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

    const [registerTxResult, registerError] = await shallPass(
      sendTransaction('TestMatcher-register', signers, args)
    )
    console.log(registerTxResult, registerError)

    const [scriptResult, scriptError] = await executeScript('Matcher-get-random-waiting-index', [])
    expect(scriptError).toBeNull()
    expect(scriptResult).toBe(0)

    const bob = await getAccountAddress("Bob")
    const args2 = [scriptResult]
    const signers2 = [bob]

    const [txResult2, error2] = await shallRevert(
      sendTransaction('TestMatcher-match', signers2, args2)
    )
    console.log(txResult2, error2)

  })

  test("match active", async () => {

    const alice = await getAccountAddress("Alice")
    const args = []
    const signers = [alice]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

    const [registerTxResult, registerError] = await shallPass(
      sendTransaction('TestMatcher-register', signers, args)
    )
    console.log(registerTxResult, registerError)

    const args2 = []
    const signers2 = [alice]

    const [txResult2, error2] = await shallPass(
      sendTransaction('TestMatcher-admin-active-match', signers2, args2)
    )
    console.log(txResult2, error2)

    const [scriptResult, scriptError] = await executeScript('Matcher-get-random-waiting-index', [])
    expect(scriptError).toBeNull()
    expect(scriptResult).toBe(0)

    const bob = await getAccountAddress("Bob")
    const args3 = [scriptResult]
    const signers3 = [bob]

    // account access
    const [txResult3, error3] = await shallRevert(
      sendTransaction('TestMatcher-match', signers3, args3)
    )
    console.log(txResult3, error3)

  })

  test("match inactive", async () => {

    const alice = await getAccountAddress("Alice")
    const args = []
    const signers = [alice]

    const [txResult, error] = await shallPass(
      sendTransaction('TestMatcher-admin-active-register', signers, args)
    )
    console.log(txResult, error)

    const [registerTxResult, registerError] = await shallPass(
      sendTransaction('TestMatcher-register', signers, args)
    )
    console.log(registerTxResult, registerError)

    const args2 = []
    const signers2 = [alice]

    const [txResult2, error2] = await shallPass(
      sendTransaction('TestMatcher-admin-active-match', signers2, args2)
    )
    console.log(txResult2, error2)

    const args3 = []
    const signers3 = [alice]

    const [txResult3, error3] = await shallPass(
      sendTransaction('TestMatcher-admin-inactive-match', signers3, args3)
    )
    console.log(txResult3, error3)

    const [scriptResult, scriptError] = await executeScript('Matcher-get-random-waiting-index', [])
    expect(scriptError).toBeNull()
    expect(scriptResult).toBe(0)

    const bob = await getAccountAddress("Bob")
    const args4 = [scriptResult]
    const signers4 = [bob]

    const [txResult4, error4] = await shallRevert(
      sendTransaction('TestMatcher-match', signers4, args4)
    )
    console.log(txResult4, error4)

  })

})