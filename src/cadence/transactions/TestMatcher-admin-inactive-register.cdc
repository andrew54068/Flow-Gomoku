import MatchContract from "./MatchContract.cdc"

transaction() {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    if let matchAdmin <- self.signer.load<@MatchContract.Admin>(from: MatchContract.AdminStoragePath) {
      matchAdmin.setActivateRegistration(true)
      MatchContract.register(host: self.signer)
      matchAdmin.setActivateRegistration(false)
      MatchContract.register(host: self.signer)
      self.signer.save(<- matchAdmin, to: MatchContract.AdminStoragePath)
    } else {
      panic("not admin")
    }
  }
}