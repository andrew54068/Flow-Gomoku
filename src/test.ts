import * as fcl from "@onflow/fcl";

(async () => {
  
  fcl.config()
  .put("env", "testnet")
  .put("accessNode.api", "https://access-testnet.onflow.org")

  const latestBlock = await fcl.latestBlock(true)
  console.log(`💥 latestBlock: ${JSON.stringify(latestBlock, null, '\t')}`)

  // const result = await fcl.send([fcl.getBlock(), fcl.atBlockHeight(68844829)]).then(fcl.decode)
  // console.log(`💥 result: ${JSON.stringify(result, null, '\t')}`)

  // get collection
  // const collection = await fcl
  // .send([
  //   fcl.getCollection(
  //     "54871f1272691fb2a371c4bbbcce0f5e62fb0c89989241af3344d8da9c82d9d2"
  //   ),
  // ])
  // .then(fcl.decode);
  // console.log(`💥 collection: ${JSON.stringify(collection, null, '\t')}`)

  // get transaction
  const transaction = await fcl.tx('b568cddcd4701bbccc69f8ce6f3b9d7faacbd77d3c3e7b25e7225d9ce1565f22').onceSealed()
  console.log(`💥 transaction: ${JSON.stringify(transaction, null, '\t')}`)

  // const result = await fcl.query({
  //   cadence: `
  //     pub fun main(a: Int, b: Int, addr: Address): Int {
  //       log(addr)
  //       return a + b
  //     }
  //   `,
  //   args: (arg, t) => [
  //     arg(7, t.Int), // a: Int
  //     arg(6, t.Int), // b: Int
  //     arg("0xba1132bc08f82fe2", t.Address), // addr: Address
  //   ],
  // });

  // console.log(result); // 13
})()