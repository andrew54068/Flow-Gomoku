import Gomoku from 0xGOMOKU_ADDRESS
import GomokuIdentity from 0xGOMOKU_IDENTITY_ADDRESS

transaction(index: UInt32) {
    let player: AuthAccount

    prepare(player: AuthAccount) {
        self.player = player
    }

    execute {
        if let compositionRef = Gomoku.getCompositionRef(by: index) {
            let identityCollectionRef = self.player
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the player's identity collection.")

            compositionRef.surrender(identityCollectionRef: identityCollectionRef)
        } else {
            panic("Composition not found.")
        }
    }
}   