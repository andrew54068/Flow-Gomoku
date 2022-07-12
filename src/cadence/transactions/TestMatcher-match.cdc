import MatchContract from "./MatchContract.cdc"

transaction(index: UInt32) {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    let host = MatchContract.match(index: index, challenger: self.signer)
    log("Hello, Cadence")
  }
}