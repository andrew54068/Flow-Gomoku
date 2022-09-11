import Gomoku from 0xGOMOKU_ADDRESS
import FlowToken from 0xFLOW_TOKEN_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import FlowToken from 0xFLOW_TOKEN_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import GomokuIdentity from 0xGOMOKU_IDENTITY_ADDRESS
import GomokuType from 0xGOMOKU_TYPE_ADDRESS

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