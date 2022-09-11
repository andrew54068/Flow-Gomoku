import MatchContract from 0xMATCH_CONTRACT_ADDRESS

transaction(index: UInt32) {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    let host = MatchContract.match(index: index, challengerAddress: self.signer.address)
  }
}