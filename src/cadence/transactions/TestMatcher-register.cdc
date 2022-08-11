import MatchContract from "./MatchContract.cdc"

transaction() {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    MatchContract.register(host: self.signer.address)
  }
}