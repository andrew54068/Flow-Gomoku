import MatchContract from 0xMATCH_CONTRACT_ADDRESS
import Gomoku from 0xGOMOKU_ADDRESS
import FlowToken from 0xFLOW_TOKEN_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import GomokuIdentity from 0xGOMOKU_IDENTITY_ADDRESS

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
                to: Gomoku.CollectionStoragePath
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