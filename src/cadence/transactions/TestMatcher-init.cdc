import MatchContract from 0xMATCH_CONTRACT_ADDRESS

transaction() {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    MatchContract.register(host: self.signer.address)
  }
}