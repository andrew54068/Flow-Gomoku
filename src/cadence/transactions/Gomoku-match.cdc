import MatchContract from "../contracts/MatchContract.cdc"
import Gomoku from "../contracts/Gomoku.cdc"
import FlowToken from "../contracts/FlowToken.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import GomokuIdentity from "../contracts/GomokuIdentity.cdc"

transaction() {
    let challenger: AuthAccount

    prepare(challenger: AuthAccount) {
        self.challenger = challenger
    }

    execute {

        fun match(): Bool {
            let waitingIndex = MatchContract.getRandomWaitingIndex() ?? panic("Waiting index not found.")

            let openingBet = Gomoku.getOpeningBet(by: waitingIndex)

            let vault: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

            let flowTokenVault = self.challenger.borrow<&FlowToken.Vault>(
                from: /storage/flowTokenVault) 
                ?? panic("Could not borrow a reference to Vault")
            vault.deposit(from: <- flowTokenVault.withdraw(amount: openingBet))

            let recycleBetReceiverRef = self.challenger
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow() ?? panic("Could not borrow a reference to the challenger recycle bet red.")

            if self.challenger
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                .borrow() == nil {
                self.challenger.save(
                    <- GomokuIdentity.createEmptyVault(),
                    to: GomokuIdentity.CollectionStoragePath)
                self.challenger.link<&GomokuIdentity.IdentityCollection>(
                    GomokuIdentity.CollectionPublicPath,
                    target: GomokuIdentity.CollectionStoragePath)
            }

            let identityCollectionRef = self.challenger
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the challenger identity collection ref.") 

            let matched = Gomoku.matchOpponent(
                index: waitingIndex,
                challenger: self.challenger.address,
                bet: <- vault,
                recycleBetVaultRef: recycleBetReceiverRef,
                identityCollectionRef: identityCollectionRef)
            return matched
        }

        let firstMatched = match()

        if firstMatched == false {
            // match again
            let secondMatched = match()
            if secondMatched {
                let collection: @GomokuIdentity.IdentityCollection <- GomokuIdentity.createEmptyVault()
                self.challenger.save(<- collection, to: GomokuIdentity.CollectionStoragePath)

                self.challenger.link<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath, target: GomokuIdentity.CollectionStoragePath)
            } else {
                panic("matched failed")
            }
        }
    }
}   