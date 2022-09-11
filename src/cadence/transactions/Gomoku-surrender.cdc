import Gomoku from 0xGOMOKU_ADDRESS
import GomokuIdentity from 0xGOMOKU_IDENTITY_ADDRESS
import GomokuResult from 0xGOMOKU_RESULT_ADDRESS

transaction(index: UInt32) {
    let player: AuthAccount

    prepare(player: AuthAccount) {
        self.player = player
    }

    execute {
        if let compositionRef = Gomoku.getCompositionRef(by: index) {
            let identityCollectionRef = self.player
                .borrow<auth &GomokuIdentity.IdentityCollection>(from: GomokuIdentity.CollectionStoragePath)
                ?? panic("Could not borrow a reference to the player's auth identity collection.")

            let resultCollectionRef = self.player
                .borrow<auth &GomokuResult.ResultCollection>(from: GomokuResult.CollectionStoragePath)
                ?? panic("Could not borrow a reference to the player's auth Gomoku result collection.")

            compositionRef.surrender(
                identityCollectionRef: identityCollectionRef,
                resultCollectionRef: resultCollectionRef
            )
        } else {
            panic("Composition not found.")
        }
    }
}   