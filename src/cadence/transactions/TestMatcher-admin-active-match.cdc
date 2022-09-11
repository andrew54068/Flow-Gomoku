import MatchContract from 0xMATCH_CONTRACT_ADDRESS

transaction() {
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    if let matchAdmin = self.signer.borrow<&MatchContract.Admin>(from: MatchContract.AdminStoragePath) {
      matchAdmin.setActivateMatching(true)
    } else {
      panic("not admin")
    }
  }
}