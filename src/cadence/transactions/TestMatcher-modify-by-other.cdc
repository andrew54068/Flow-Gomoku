import MatchContract from 0xMATCH_CONTRACT_ADDRESS

transaction() {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    MatchContract.matchedIndices.remove(at: 0)
  }
}