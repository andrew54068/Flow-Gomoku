import MatchContract from "./MatchContract.cdc"
import Gomoku from "./Gomoku.cdc"

transaction() {
    let host: AuthAccount

    prepare(host: AuthAccount) {
        self.host = host
    }

    execute {

        // flow token
        let capability = challenger.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver)

        let flowTokenVault = self.challenger.borrow<&FlowToken.Vault>(
          from: /storage/flowTokenVault) 
          ?? panic("Could not borrow a reference to Vault")
        let vault <- flowTokenVault.withdraw(amount: openingBet) as! @FlowToken.Vault

        let composition <- Gomoku.register(
            host: host,
            openingBet: <- vault)

        // Create a new Gomoku and put it in storage
        host.save(<- composition, to: Gomoku.CollectionStoragePath)

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        host.link<&Gomoku.Composition{Gomoku.PublicCompositioning}>(
            Gomoku.CollectionPublicPath,
            target: Gomoku.CollectionStoragePath
        )

        let identityToken <- Gomoku.claim(host: host)

        // Create a new Gomoku and put it in storage
        host.save(<- identityToken, to: Gomoku.Composition.IdentityStoragePath)

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        host.link<&Gomoku.Composition{Gomoku.Composition.IdentityPublicPath}>(
            Gomoku.Composition.IdentityPublicPath,
            target: Gomoku.Composition.IdentityStoragePath
        )

        if let identityToken: @IdentityToken <- Gomoku.matchOpponent(
            index: waitingIndex,
            challenger: challenger.address,
            bet: <- vault) {
            self.challenger.save(<- identityToken, to: Gomoku.Composition.IdentityStoragePath)
            
            // Create a public capability to the Vault that only exposes
            // the deposit function through the Receiver interface
            self.challenger.link<&Gomoku.Composition{Gomoku.Composition.IdentityPublicPath}>(
                Gomoku.Composition.IdentityPublicPath,
                target: Gomoku.Composition.IdentityStoragePath
            )
        } else {
            panic("not matched.")
        }
    }
}