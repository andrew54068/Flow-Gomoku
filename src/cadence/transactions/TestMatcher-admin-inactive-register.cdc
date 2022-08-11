import MatchContract from "./MatchContract.cdc"

transaction() {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    if let matchAdmin = self.signer.borrow<&MatchContract.Admin>(from: MatchContract.AdminStoragePath) {
      matchAdmin.setActivateRegistration(true)
      MatchContract.register(host: self.signer.address)
      matchAdmin.setActivateRegistration(false)
      MatchContract.register(host: self.signer.address)
    } else {
      panic("not admin")
    }
  }
}