import GomokuIdentifying from "./GomokuIdentifying.cdc"

pub contract interface GomokuCompositioning {
    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Transactions
    access(account) fun createComposition(
        id: UInt32,
        host: Address,
        boardSize: UInt8,
        totalRound: UInt8
    ): @AnyResource{CompositionCollecting}

    access(account) fun createEmptyVault(): @AnyResource{CompositionCollecting}

    pub resource interface Compositioning {
        pub let id: UInt32

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: UInt8
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

        // Script
        pub fun getTimeout(): UInt64
        pub fun getStoneData(for round: UInt8): [AnyStruct{StoneDataing}]
        pub fun getParticipants(): [Address]

        // Transaction
        pub fun makeMove(
            identityToken: @AnyResource{GomokuIdentifying.IdentityTokening},
            stone: @AnyResource{Stoning},
            raisedBet: @FlowToken.Vault,
            hasRoundWinnerCallback: ((Bool): Void)
        ): @AnyResource{GomokuIdentifying.IdentityTokening}?
        pub fun surrender(
            identityCollectionRef: &AnyResource{GomokuIdentifying.IdentityCollecting}
        )
        access(account) fun match(
            identityCollectionRef: &AnyResource{GomokuIdentifying.IdentityCollecting},
            challenger: Address
        )
        access(account) fun finalizeByTimeout(
            identityToken: @AnyResource{GomokuIdentifying.IdentityTokening}
        ): @AnyResource{GomokuIdentifying.IdentityTokening}?
    }

    pub resource interface CompositionCollecting {
        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        pub fun getIds(): [UInt32]
        pub fun getBalance(): Int
        pub fun borrow(id: UInt32): &AnyResource{Compositioning}?


        access(account) fun withdraw(by id: UInt32): @AnyResource{Compositioning}?
        access(account) fun deposit(token: @AnyResource{Compositioning})
    }
}