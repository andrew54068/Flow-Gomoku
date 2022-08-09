import GomokuType from "./GomokuType.cdc"

pub contract interface GomokuResulting {
    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Transactions
    access(account) fun createResult(
        id: UInt32,
        winner: Address?,
        losser: Address?,
        gain: Fix64,
        steps: [[AnyStruct{GomokuType.StoneDataing}]]
    ): @AnyResource{ResultTokening}

    access(account) fun createEmptyVault(): @AnyResource{ResultCollecting}

    pub resource interface ResultTokening {
        pub let id: UInt32
        pub let winner: Address?
        pub let losser: Address?
        pub let isDraw: Bool
        pub let gain: Fix64

        // Scripts
        pub fun getSteps(round: UInt32): [AnyStruct{GomokuType.StoneDataing}]

        // Transactions
        access(account) fun setDestroyable(_ value: Bool)
    }

    pub resource interface ResultCollecting {
        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        pub fun getIds(): [UInt32]
        pub fun borrow(id: UInt32): &AnyResource{GomokuResulting.ResultTokening}?
        pub fun getBalance(): Int


        access(account) fun withdraw(by id: UInt32): @AnyResource{GomokuResulting.ResultTokening}?
        access(account) fun deposit(token: @AnyResource{GomokuResulting.ResultTokening})
    }
}