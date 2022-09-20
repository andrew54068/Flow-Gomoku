import MatchContract from 0xMATCH_CONTRACT_ADDRESS
import Gomoku from 0xGOMOKU_ADDRESS
import FlowToken from 0xFLOW_TOKEN_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import GomokuIdentity from 0xGOMOKU_IDENTITY_ADDRESS
import GomokuResult from 0xGOMOKU_RESULT_ADDRESS

transaction(openingBet: UFix64, index: UInt32) {
    let challenger: AuthAccount
    let flowTokenVault: &FlowToken.Vault

    prepare(challenger: AuthAccount) {
        self.challenger = challenger
        self.flowTokenVault = self.challenger.borrow<&FlowToken.Vault>(
            from: /storage/flowTokenVault) 
            ?? panic("Could not borrow a reference to Vault")
    }

    pre {
        self.flowTokenVault.balance >= openingBet: "Flow token not enough."
    }

    execute {
        let participants = Gomoku.getParticipants(by: index)
        assert(participants.length > 0, message: "There are no composition index: ".concat(index.toString()).concat(" exist."))
        assert(participants.length != 2, message: "Composition already matched.")

        let hostOpeningBet = Gomoku.getHostOpeningBet(by: index) ?? UFix64(0)
        assert(openingBet >= hostOpeningBet, message: "OpeningBet not matched.")

        let vault: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

        vault.deposit(from: <- self.flowTokenVault.withdraw(amount: hostOpeningBet))

        let recycleBetReceiverRef = self.challenger
            .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            .borrow() ?? panic("Could not borrow a reference to the challenger recycle bet.")


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
            .borrow<auth &GomokuIdentity.IdentityCollection>(from: GomokuIdentity.CollectionStoragePath)
            ?? panic("Could not borrow a reference to auth Gomoku identity collection.") 


        if self.challenger
            .getCapability<&GomokuResult.ResultCollection>(GomokuResult.CollectionPublicPath)
            .borrow() == nil {
            self.challenger.save(
                <- GomokuResult.createEmptyVault(),
                to: GomokuResult.CollectionStoragePath
            )
            self.challenger.link<&GomokuResult.ResultCollection>(
                GomokuResult.CollectionPublicPath,
                target: GomokuResult.CollectionStoragePath
            )
        }
        let resultCollectionRef = self.challenger
            .borrow<auth &GomokuResult.ResultCollection>(from: GomokuResult.CollectionStoragePath)
            ?? panic("Could not borrow a reference to auth Gomoku result collection.")
 

        let matched = Gomoku.matchOpponent(
            index: index,
            challenger: self.challenger.address,
            bet: <- vault,
            recycleBetVaultRef: recycleBetReceiverRef,
            identityCollectionRef: identityCollectionRef,
            resultCollectionRef: resultCollectionRef
        )
        assert(matched, message: "Match failed! Raise your openingBet or open one your own.")
        return
    }
}   