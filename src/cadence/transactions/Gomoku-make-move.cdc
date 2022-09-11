import Gomoku from 0xGOMOKU_ADDRESS
import FlowToken from 0xFLOW_TOKEN_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import GomokuIdentity from 0xGOMOKU_IDENTITY_ADDRESS
import GomokuResult from 0xGOMOKU_RESULT_ADDRESS
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
                .borrow<auth &GomokuIdentity.IdentityCollection>(from: GomokuIdentity.CollectionStoragePath)
                ?? panic("Could not borrow a reference to the player's auth Gomoku identity collection.")

            let location = GomokuType.StoneLocation(
                x: x,
                y: y
            )

            let resultCollectionRef = self.player
                .borrow<auth &GomokuResult.ResultCollection>(from: GomokuResult.CollectionStoragePath)
                ?? panic("Could not borrow a reference to the player's auth Gomoku result collection.")

            compositionRef.makeMove(
                identityCollectionRef: identityCollectionRef,
                resultCollectionRef: resultCollectionRef,
                location: location,
                raisedBet: <- self.raiseBetTokenVault
            )
        } else {
            panic("Composition not found.")
        }
    }
}   