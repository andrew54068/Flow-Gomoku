import MatchContract from "../contracts/MatchContract.cdc"
import Gomoku from "../contracts/Gomoku.cdc"
import FlowToken from "../contracts/FlowToken.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import GomokuIdentity from "../contracts/GomokuIdentity.cdc"

transaction(openingBet: UFix64) {
    let host: AuthAccount

    prepare(host: AuthAccount) {
        self.host = host
    }

    execute {

        assert(self.host.availableBalance > openingBet, message: "Flow token is insufficient.")

        let flowTokenVault = self.host.borrow<&FlowToken.Vault>(
          from: /storage/flowTokenVault) 
          ?? panic("Could not borrow a reference to Flow token vault")

        if self.host.borrow<&GomokuIdentity.IdentityCollection>(from: GomokuIdentity.CollectionStoragePath) == nil {
            self.host.save(
                <- GomokuIdentity.createEmptyVault(),
                to: GomokuIdentity.CollectionStoragePath
            )
            self.host.link<&GomokuIdentity.IdentityCollection>(
                GomokuIdentity.CollectionPublicPath,
                target: GomokuIdentity.CollectionStoragePath
            )
        }

        let identityCollectionRef = self.host.borrow<&GomokuIdentity.IdentityCollection>(from: GomokuIdentity.CollectionStoragePath)
          ?? panic("Could not borrow a reference to GomokuIdentity IdentityCollection")

        if self.host.borrow<&Gomoku.CompositionCollection>(from: Gomoku.CollectionStoragePath) == nil {
            self.host.save(
                <- Gomoku.createEmptyVault(),
                to: GomokuIdentity.CollectionStoragePath
            )
            self.host.link<&Gomoku.CompositionCollection>(
                Gomoku.CollectionPublicPath,
                target: Gomoku.CollectionStoragePath
            )
        }

        let compositionCollectionRef = self.host.borrow<&Gomoku.CompositionCollection>(from: Gomoku.CollectionStoragePath)
          ?? panic("Could not borrow a reference to Gomoku CompositionCollection")


        let vault <- flowTokenVault.withdraw(amount: openingBet) as! @FlowToken.Vault

        Gomoku.register(
            host: self.host.address,
            openingBet: <- vault,
            identityCollectionRef: identityCollectionRef,
            compositionCollectionRef: compositionCollectionRef)

    }
}