import MatchContract from "../contracts/MatchContract.cdc"
import Gomoku from "../contracts/Gomoku.cdc"
import FlowToken from "../contracts/FlowToken.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import GomokuIdentity from "../contracts/GomokuIdentity.cdc"
import GomokuType from "../contracts/GomokuType.cdc"

transaction(index: UInt32, x: Int8, y: Int8, bet: UFix64) {
    let player: AuthAccount
    let raiseBetTokenVault: @FlowToken.Vault

    prepare(player: AuthAccount) {
        self.player = player
        let flowTokenVault = self.player.borrow<&FlowToken.Vault>(
            from: /storage/flowTokenVault) 
            ?? panic("Could not borrow a reference to Vault")
        self.raiseBetTokenVault <- flowTokenVault.withdraw(amount: bet) as! @FlowToken.Vault
    }

    execute {
        if let compositionRef = Gomoku.getCompositionRef(by: index) {
            let identityCollectionRef = self.player
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the player's identity collection.")

            let location = GomokuType.StoneLocation(
                x: x,
                y: y
            )

            compositionRef.makeMove(
                identityCollectionRef: identityCollectionRef,
                location: location,
                raisedBet: <- self.raiseBetTokenVault
            )
        } else {
            panic("Composition not found.")
        }
    }
}   