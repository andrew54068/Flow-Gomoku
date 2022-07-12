import MatchContract from "./MatchContract.cdc"

transaction() {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    if let matchAdmin <- self.signer.load<@MatchContract.Admin>(from: MatchContract.AdminStoragePath) {
      matchAdmin.setActivateMatching(true)
      self.signer.save(<- matchAdmin, to: MatchContract.AdminStoragePath)
    } else {
      panic("not admin")
    }
  }
}