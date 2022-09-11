import MatchContract from 0xMATCH_CONTRACT_ADDRESS
import Gomoku from 0xGOMOKU_ADDRESS
import FlowToken from 0xFLOW_TOKEN_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import GomokuIdentity from 0xGOMOKU_IDENTITY_ADDRESS
import GomokuResult from 0xGOMOKU_RESULT_ADDRESS

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

        if self.host
            .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
            .borrow() == nil {
            self.host.save(
                <- GomokuIdentity.createEmptyVault(),
                to: GomokuIdentity.CollectionStoragePath
            )
            self.host.link<&GomokuIdentity.IdentityCollection>(
                GomokuIdentity.CollectionPublicPath,
                target: GomokuIdentity.CollectionStoragePath
            )
        }
        let identityCollectionRef = self.host
            .borrow<auth &GomokuIdentity.IdentityCollection>(from: GomokuIdentity.CollectionStoragePath)
            ?? panic("Could not borrow a reference to auth Gomoku identity collection.")


        if self.host
            .getCapability<&GomokuResult.ResultCollection>(GomokuResult.CollectionPublicPath)
            .borrow() == nil {
            self.host.save(
                <- GomokuResult.createEmptyVault(),
                to: GomokuResult.CollectionStoragePath
            )
            self.host.link<&GomokuResult.ResultCollection>(
                GomokuResult.CollectionPublicPath,
                target: GomokuResult.CollectionStoragePath
            )
        }
        let resultCollectionRef = self.host
            .borrow<auth &GomokuResult.ResultCollection>(from: GomokuResult.CollectionStoragePath)
            ?? panic("Could not borrow a reference to auth Gomoku result collection.")


        if self.host
            .getCapability<&Gomoku.CompositionCollection>(Gomoku.CollectionPublicPath)
            .borrow() == nil {
            self.host.save(
                <- Gomoku.createEmptyVault(),
                to: Gomoku.CollectionStoragePath
            )
            self.host.link<&Gomoku.CompositionCollection>(
                Gomoku.CollectionPublicPath,
                target: Gomoku.CollectionStoragePath
            )
        }
        let compositionCollectionRef = self.host
            .borrow<auth &Gomoku.CompositionCollection>(from: Gomoku.CollectionStoragePath)
            ?? panic("Could not borrow a reference to auth Gomoku composition collection")


        let vault <- flowTokenVault.withdraw(amount: openingBet) as! @FlowToken.Vault

        Gomoku.register(
            host: self.host.address,
            openingBet: <- vault,
            identityCollectionRef: identityCollectionRef,
            resultCollectionRef: resultCollectionRef,
            compositionCollectionRef: compositionCollectionRef)

    }
}