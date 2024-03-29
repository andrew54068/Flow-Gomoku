import MatchContract from 0xMATCH_CONTRACT_ADDRESS
import Gomoku from 0xGOMOKU_ADDRESS
import FlowToken from 0xFLOW_TOKEN_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import GomokuIdentity from 0xGOMOKU_IDENTITY_ADDRESS
import GomokuResult from 0xGOMOKU_RESULT_ADDRESS

transaction(budget: UFix64) {
    let challenger: AuthAccount
    let flowTokenVault: &FlowToken.Vault

    prepare(challenger: AuthAccount) {
        self.challenger = challenger
        self.flowTokenVault = self.challenger.borrow<&FlowToken.Vault>(
            from: /storage/flowTokenVault) 
            ?? panic("Could not borrow a reference to Vault")
    }

    pre {
        self.flowTokenVault.balance >= budget: "Flow token not enough."
    }

    execute {

        let waitingIndex = MatchContract.getRandomWaitingIndex() ?? panic("Waiting index not found.")

        var index = waitingIndex

        while (Gomoku.getHostOpeningBet(by: index) ?? UFix64(0)) > budget
            || Gomoku.getParticipants(by: index).length != 1 {
            if Gomoku.getParticipants(by: index).length == 0 {
                panic("Match failed at index".concat(index.toString()))
            }
            index = index + 1
        }

        let vault: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

        let hostOpeningBet = Gomoku.getHostOpeningBet(by: index) ?? UFix64(0)
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
        assert(matched, message: "Match failed! Raise your budget or open one your own.")
        return
    }
}   