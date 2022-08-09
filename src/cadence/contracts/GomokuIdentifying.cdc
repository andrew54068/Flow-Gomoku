import GomokuType from "./GomokuType.cdc"

pub contract interface GomokuIdentifying {
    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    access(account) fun createIdentity(
        id: UInt32,
        address: Address,
        role: GomokuType.Role,
        stoneColor: GomokuType.StoneColor
    ): @AnyResource{IdentityTokening}

    access(account) fun createEmptyVault(): @AnyResource{IdentityCollecting}

    pub resource interface IdentityTokening {
        pub let id: UInt32
        pub let address: Address
        pub let role: GomokuType.Role
        pub var stoneColor: GomokuType.StoneColor

        access(account) fun switchIdentity()
        access(account) fun setDestroyable(_ value: Bool)
    }

    pub resource interface IdentityCollecting {
        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        pub fun getIds(): [UInt32]
        pub fun getBalance(): Int
        pub fun borrow(id: UInt32): &AnyResource{IdentityTokening}?

        access(account) fun withdraw(by id: UInt32): @AnyResource{IdentityTokening}?
        access(account) fun deposit(token: @AnyResource{IdentityTokening})
    }
}