 import Gomoku from "./Gomoku.cdc"
 import GomokuComposition from "./GomokuComposition.cdc"

pub contract GomokuIdentity {

    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Events
    pub event Create(id: UInt32, address: Address, role: Gomoku.Role)
    pub event CollectionCreated()
    pub event Withdraw(id: UInt32, from: Address?)
    pub event Deposit(id: UInt32, to: Address?)

    init() {
        self.CollectionStoragePath = /storage/gomokuIdentityCollection
        self.CollectionPublicPath = /public/gomokuIdentityCollection
    }

    pub resource interface IdentitySwitching {
        access(account) fun switchIdentity()
    }

    pub resource IdentityToken: IdentitySwitching {
        pub let id: UInt32
        pub let address: Address
        pub let role: Gomoku.Role
        pub var stoneColor: GomokuComposition.StoneColor

        priv var destroyable: Bool

        init(
            id: UInt32,
            address: Address,
            role: Gomoku.Role,
            stoneColor: GomokuComposition.StoneColor
        ) {
            self.id = id
            self.address = address
            self.role = role
            self.stoneColor = stoneColor
            self.destroyable = false
        }

        access(account) fun switchIdentity() {
            switch self.stoneColor {
            case GomokuComposition.StoneColor.black:
                self.stoneColor = GomokuComposition.StoneColor.white
            case GomokuComposition.StoneColor.white:
                self.stoneColor = GomokuComposition.StoneColor.black
            }
        }

        access(account) fun setDestroyable(_ value: Bool) {
            self.destroyable = value
        }

        destroy() {
            if self.destroyable == false {
                panic("You can't destroy this token before setting destroyable to true.")
            }
        }
    }

    access(self) fun createIdentity(
        id: UInt32,
        address: Address,
        role: Gomoku.Role,
        stoneColor: GomokuComposition.StoneColor
    ): @IdentityToken {
        emit Create(
            id: id, 
            address: address, 
            role: role)

        return <- create IdentityToken(
            id: id,
            address: address,
            role: role,
            stoneColor: stoneColor
        )
    }

    pub resource IdentityCollection {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        priv var ownedIdentityTokenMap: @{UInt32: IdentityToken}
        priv var destroyable: Bool

        init () {
            self.ownedIdentityTokenMap <- {}
            self.destroyable = false
            self.StoragePath = /storage/compositionIdentity
            self.PublicPath = /public/compositionIdentity
        }

        access(account) fun withdraw(by id: UInt32): @IdentityToken {
            let token <- self.ownedIdentityTokenMap.remove(key: id) ?? panic("missing Composition")
            emit Withdraw(id: token.id, from: self.owner?.address)
            if self.ownedIdentityTokenMap.keys.length == 0 {
                self.destroyable = true
            }
            return <- token
        }

        access(account) fun deposit(token: @IdentityToken) {
            let token <- token
            let id: UInt32 = token.id
            let oldToken <- self.ownedIdentityTokenMap[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            self.destroyable = false
            destroy oldToken
        }

        pub fun getIds(): [UInt32] {
            return self.ownedIdentityTokenMap.keys
        }

        pub fun getBalance(): Int {
            return self.ownedIdentityTokenMap.keys.length
        }

        pub fun borrow(id: UInt32): &IdentityToken {
            return (&self.ownedIdentityTokenMap[id] as &Gomoku.IdentityToken?)!
        }

        destroy() {
            destroy self.ownedIdentityTokenMap
            if self.destroyable == false {
                panic("Ha Ha! Got you! You can't destory this collection if there are Gomoku Composition!")
            }
        }
    }

    access(self) fun createEmptyVault(): @CompositionCollection {
        emit CollectionCreated()
        return <- create IdentityCollection()
    }
}