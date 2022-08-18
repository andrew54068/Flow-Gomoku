import FlowToken from "./FlowToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import GomokuIdentifying from "./GomokuIdentifying.cdc"
import GomokuType from "./GomokuType.cdc"

pub contract interface Gomokuing {

    access(account) let hostOpeningBetMap: @{ UInt32: FlowToken.Vault }
    access(account) let challengerOpeningBetMap: @{ UInt32: FlowToken.Vault }

    access(account) let hostRaisedBetMap: @{ UInt32: FlowToken.Vault }
    access(account) let challengerRaisedBetMap: @{ UInt32: FlowToken.Vault }

    // Scripts
    pub fun getCompositionRef(by index: UInt32): &AnyResource{Compositioning}?
    pub fun getParticipants(by index: UInt32): [Address]
    pub fun getOpeningBet(by index: UInt32): UFix64
    pub fun getValidBets(by index: UInt32): UFix64

    // Transaction
    pub fun register(
        host: Address,
        openingBet: @FlowToken.Vault,
        identityCollectionRef: &AnyResource{GomokuIdentifying.IdentityCollecting},
        compositionCollectionRef: &AnyResource{CompositionCollecting}
    )

    pub fun matchOpponent(
        index: UInt32,
        challenger: Address,
        bet: @FlowToken.Vault,
        recycleBetVaultRef: &FlowToken.Vault{FungibleToken.Receiver},
        identityCollectionRef: &AnyResource{GomokuIdentifying.IdentityCollecting}
    ): Bool

    access(account) fun createComposition(
        id: UInt32,
        host: Address,
        boardSize: UInt8,
        totalRound: UInt8
    ): @AnyResource{Compositioning}

    pub fun createEmptyVault(): @AnyResource{CompositionCollecting}

    pub resource interface Compositioning {
        pub let id: UInt32

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: UInt8
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

        // Script
        pub fun getTimeout(): UInt64
        pub fun getStoneData(for round: UInt8): [AnyStruct{GomokuType.StoneDataing}]
        pub fun getParticipants(): [Address]

        // Transaction
        pub fun makeMove(
            identityToken: @AnyResource{GomokuIdentifying.IdentityTokening},
            stone: @AnyResource{GomokuType.Stoning},
            raisedBet: @FlowToken.Vault,
            hasRoundWinnerCallback: ((Bool): Void)
        ): @AnyResource{GomokuIdentifying.IdentityTokening}?
        pub fun surrender(
            identityToken: @AnyResource{GomokuIdentifying.IdentityTokening}
        ): @AnyResource{GomokuIdentifying.IdentityTokening}?
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