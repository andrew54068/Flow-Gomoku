import * as dotenv from 'dotenv'
import * as fcl from "@onflow/fcl"
import { SHA3 } from "sha3"
import * as elliptic from "elliptic"
import * as fs from 'fs';

dotenv.config()

const ADDRESS = process.env.testnet_admin_address || ''
const PRIVATE_KEY = process.env.testnet_admin_private_key || ''

const ec = new elliptic.ec('p256')

const signWithKey = (privateKey: string, msgHex: string): string => {
  const key = ec.keyFromPrivate(Buffer.from(privateKey, 'hex'))
  const sig = key.sign(hashMsgHex(msgHex))
  const n = 32 // half of signature length?
  const r = sig.r.toArrayLike(Buffer, 'be', n)
  const s = sig.s.toArrayLike(Buffer, 'be', n)
  return Buffer.concat([r, s]).toString('hex')
}

const hashMsgHex = (msgHex: string) => {
  const sha = new SHA3(256)
  sha.update(Buffer.from(msgHex, 'hex'))
  return sha.digest()
}

const getAccount = async (addr: string) => {
  const { account } = await fcl.send([fcl.getAccount(addr)])
  return account
}

const authorization = async (account: {
  role: {
    proposer: boolean
  },
  roles: string[],
  signature: string
}) => {
  const user = await getAccount(ADDRESS)
  const key = user.keys[0]

  let sequenceNum
  if (account.role && account.role.proposer) sequenceNum = key.sequenceNumber

  const signingFunction = async (data: any) => {
    const sig = signWithKey(PRIVATE_KEY, data.message)
    return {
      addr: user.address,
      keyId: key.index,
      signature: sig,
    }
  }

  return {
    ...account,
    addr: user.address,
    keyId: key.index,
    sequenceNum,
    signature: account.signature || null,
    signingFunction,
    resolve: null,
    roles: account.roles,
  }
}

const sendTransaction = async (script: string, args = []) =>
  fcl
    .send([fcl.getBlock(true)])
    .then(fcl.decode)
    .then((block: any) => fcl.send([
      fcl.transaction(script),
      fcl.args(args),
      fcl.authorizations([authorization]),
      fcl.proposer(authorization),
      fcl.payer(authorization),
      fcl.ref(block.id),
      fcl.limit(100),
    ]))
    .then(({ transactionId }: { transactionId: string }) => fcl.tx(transactionId).onceSealed())
    .catch((e: any) => {
      console.error(e)
    })

;(async () => {
  fcl.config()
    .put("flow.network", "testnet")
    .put("accessNode.api", "https://rest-testnet.onflow.org")
    .put("0xFUNGIBLE_TOKEN_ADDRESS", "0x9a0766d93b6608b7")
    .put("0xFLOW_TOKEN_ADDRESS", "0x7e60df042a9c0868")
    .put("0xMATCH_CONTRACT_ADDRESS", "0x41109bacd023370f")
    .put("0xGOMOKU_TYPE_ADDRESS", "0x41109bacd023370f")
    .put("0xGOMOKU_IDENTITY_ADDRESS", "0x41109bacd023370f")
    .put("0xGOMOKU_RESULT_ADDRESS", "0x41109bacd023370f")
    .put("0xGOMOKU_ADDRESS", "0x41109bacd023370f")

  var script = fs.readFileSync("./src/cadence/transactions/Matcher-admin-active-register-match.cdc").toString('utf-8');
  let result = await sendTransaction(script)
  console.log(`💥 result: ${JSON.stringify(result, null, '\t')}`)

    /* mainnet
    fcl.config()
    .put("flow.network", "mainnet")
    .put("accessNode.api", "https://access-mainnet-beta.onflow.org")
    .put("0xFUNGIBLE_TOKEN_ADDRESS", "0xf233dcee88fe0abe")
    .put("0xFLOW_TOKEN_ADDRESS", "0x1654653399040a61")
    .put("0xMATCH_CONTRACT_ADDRESS", "not yet deployed")
    .put("0xGOMOKU_TYPE_ADDRESS", "not yet deployed")
    .put("0xGOMOKU_IDENTITY_ADDRESS", "not yet deployed")
    .put("0xGOMOKU_RESULT_ADDRESS", "not yet deployed")
    .put("0xGOMOKU_ADDRESS", "not yet deployed")
    */

})()