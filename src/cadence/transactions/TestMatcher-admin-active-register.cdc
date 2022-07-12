import MatchContract from "./MatchContract.cdc"

transaction() {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    if let matchAdmin <- self.signer.load<@MatchContract.Admin>(from: MatchContract.AdminStoragePath) {
      matchAdmin.setActivateRegistration(true)
      self.signer.save(<- matchAdmin, to: MatchContract.AdminStoragePath)
      MatchContract.register(host: self.signer)
    } else {
      panic("not admin")
    }
  }
}