import MatchContract from "../contracts/MatchContract.cdc"
import Gomoku from "../contracts/Gomoku.cdc"
import FlowToken from "../contracts/FlowToken.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import GomokuIdentity from "../contracts/GomokuIdentity.cdc"

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

        while (Gomoku.getOpeningBet(by: index) ?? UFix64(0)) > budget 
            || Gomoku.getParticipants(by: index).length != 1 {
            if Gomoku.getParticipants(by: index).length == 0 {
                panic("Match failed.")
            }
            index = index + 1
        }

        let openingBet = Gomoku.getOpeningBet(by: index) ?? UFix64(0)

        let vault: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

        vault.deposit(from: <- self.flowTokenVault.withdraw(amount: openingBet))

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
            index: index,
            challenger: self.challenger.address,
            bet: <- vault,
            recycleBetVaultRef: recycleBetReceiverRef,
            identityCollectionRef: identityCollectionRef)
        assert(matched, message: "Match failed! Raise your budget or open one your own.")
        return
    }
}   