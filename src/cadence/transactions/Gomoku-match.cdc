import MatchContract from "./MatchContract.cdc"
import Gomoku from "./Gomoku.cdc"

transaction() {
    let challenger: AuthAccount

    prepare(challenger: AuthAccount) {
        self.challenger = challenger
    }

    execute {
        let waitingIndex = MatchContract.getRandomWaitingIndex()

        let openingBetType = Gomoku.getOpeningBetType()
        let openingBet = Gomoku.getOpeningBet()

        let vault: @FungibleToken.Vault
        let recycleBetReceiverRef: &FungibleToken.Receiver
        if openingBetType == Type<@FlowToken.Vault>() {
            // flow token
            let flowTokenVault = self.challenger.borrow<&FlowToken.Vault>(
              from: /storage/flowTokenVault) 
              ?? panic("Could not borrow a reference to Vault")
            vault <- flowTokenVault.withdraw(amount: openingBet) as! @FlowToken.Vault

            let capability = self.challenger.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            recycleBetReceiverRef = capability.borrow() ?? panic("Could not borrow a reference to the challenger capability.")
        } else if openingBetType == Type<@BloctoToken.Vault>() {
            // blocto token
            let bltTokenVault = self.challenger.borrow<&BloctoToken.Vault>(
              from: BloctoToken.TokenPublicBalancePath) 
              ?? panic("Could not borrow a reference to Vault")

            vault <- bltTokenVault.withdraw(amount: openingBet) as! @BloctoToken.Vault

            let capability = self.challenger.getCapability<&AnyResource{FungibleToken.Receiver}>(BloctoToken.TokenPublicReceiverPath)
            recycleBetReceiverRef = capability.borrow() ?? panic("Could not borrow a reference to the challenger capability.")
        } else if openingBetType == Type<@TeleportedTetherToken.Vault>() {
            // TeleportedTetherToken token
            let teleportedTetherTokenVault = self.challenger.borrow<&TeleportedTetherToken.Vault>(
              from: TeleportedTetherToken.TokenStoragePath) 
              ?? panic("Could not borrow a reference to Vault")

            vault <- teleportedTetherTokenVault.withdraw(amount: openingBet) as! @TeleportedTetherToken.Vault

            let capability = self.challenger.getCapability<&AnyResource{FungibleToken.Receiver}>(TeleportedTetherToken.TokenPublicReceiverPath)
            recycleBetReceiverRef = capability.borrow() ?? panic("Could not borrow a reference to the challenger capability.")
        } else {
            panic("Only support Flow Token, Blocto Token, tUSDT right now.")
        }

        if let identityToken: @IdentityToken <- Gomoku.matchOpponent(
            index: waitingIndex,
            challenger: challenger.address,
            bet: <- vault,
            recycleBetVaultRef: recycleBetReceiverRef) {
            self.challenger.save(<- identityToken, to: Gomoku.Composition.IdentityStoragePath)

            // Create a public capability to the IdentityToken that only exposes
            // the switching function through the Gomoku.IdentitySwitching interface
            self.challenger.link<&Gomoku.IdentityToken{Gomoku.IdentitySwitching}>(
                Gomoku.Composition.IdentityPublicPath,
                target: Gomoku.Composition.IdentityStoragePath
            )
        } else {
            panic("not matched.")
        }
    }
}   