import * as fcl from "@onflow/fcl"

(async () => {
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


})()