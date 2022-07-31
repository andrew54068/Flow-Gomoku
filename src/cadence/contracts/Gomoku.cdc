import MatchContract from "./MatchContract.cdc"
import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
// import FlowToken from 0x0ae53cb6e3f42a79
import FlowToken from "./FlowToken.cdc"


import GomokuComposition from "./GomokuComposition.cdc"
import GomokuIdentity from "./GomokuIdentity.cdc"

pub contract Gomoku {

    // Bets
    priv let hostOpeningBetMap: @{ UInt32: FlowToken.Vault }
    priv let challengerOpeningBetMap: @{ UInt32: FlowToken.Vault }

    priv let hostRaisedBetMap: @{ UInt32: FlowToken.Vault }
    priv let challengerRaisedBetMap: @{ UInt32: FlowToken.Vault }

    // Events
    // Event be emitted when the composition is created
    pub event HostOpeningBet(balance: UFix64)

    // Event be emitted when the contract is created
    pub event CompositionMatched(
        host: Address,
        challenger: Address,
        currency: String,
        openingBet: UFix64)

    init() {

        self.hostOpeningBetMap <- {}
        self.challengerOpeningBetMap <- {}
        self.hostRaisedBetMap <- {}
        self.challengerRaisedBetMap <- {}

        if self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
            let flowVault <- FlowToken.createEmptyVault()
            self.account.save(<- flowVault, to: /storage/flowTokenVault)
        }

        if self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver) == nil {
            // Create a public capability to the stored Vault that only exposes
            // the `deposit` method through the `Receiver` interface
            self.account.link<&FlowToken.Vault{FungibleToken.Receiver}>(
                /public/flowTokenReceiver,
                target: /storage/flowTokenVault
            )
        }

        if self.account.getCapability<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance) == nil {
            // Create a public capability to the stored Vault that only exposes
            // the `balance` field through the `Balance` interface
            self.account.link<&FlowToken.Vault{FungibleToken.Balance}>(
                /public/flowTokenBalance,
                target: /storage/flowTokenVault
            )
        }
    }

    // Scripts
    pub fun getCompositionRef(by index: UInt32): &AnyResource{Gomoku.PublicCompositioning}? {
        if let host = MatchContract.getHostAddress(by: index) {
            let publicCapability = getAccount(host).getCapability(GomokuComposition.CollectionPublicPath)
            return publicCapability.borrow<&Gomoku.Composition{Gomoku.PublicCompositioning}>()
        } else {
            return nil
        }
    }

    pub fun getParticipants(by index: UInt32): [Address] {
        return self.getCompositionRef(by: index)?.getParticipants() ?? []
    }

    // Opening bets
    pub fun getOpeningBet(by index: UInt32): UFix64 {
        let hostBet = self.hostOpeningBetMap[index]?.balance ?? UFix64(0)
        let challengerBet = self.challengerOpeningBetMap[index]?.balance ?? UFix64(0)
        return hostBet + challengerBet
    }

    // Opening bets + raised bets
    pub fun getValidBets(by index: UInt32): UFix64 {
        let bet = self.getOpeningBet(by: index)
        let hostRaisedBet = self.hostRaisedBetMap[index]?.balance ?? UFix64(0)
        let challengerRaisedBet = self.challengerRaisedBetMap[index]?.balance ?? UFix64(0)
        if hostRaisedBet >= challengerRaisedBet {
            return bet + (challengerRaisedBet * UFix64(2))
        } else {
            return bet + (hostRaisedBet * UFix64(2))
        }
    }

    // Transaction
    pub fun register(
        host: Address,
        openingBet: @FlowToken.Vault,
        identityHandler: ((@GomokuIdentity.IdentityToken): Void)
    ): @GomokuComposition.Composition {
        let index = MatchContract.register(host: host)

        let vaultRef = &openingBet as &FlowToken.Vault
        let betBalance: UFix64 = vaultRef.balance
        if self.hostOpeningBetMap.keys.contains(index) {
            let balance = self.hostOpeningBetMap[index]?.balance ?? UFix64(0)
            assert(balance == UFix64(0), message: "Already registered.")

            var tempVault: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            // self.hostOpeningBetMap[index] <-> tempVault

            tempVault.deposit(from: <- openingBet)

            let empty <- self.hostOpeningBetMap[index] <- tempVault
            destroy empty
        } else {
            self.hostOpeningBetMap[index] <-! openingBet
        }

        let identity <- GomokuIdentity.createIdentity(
            id: index,
            address: host,
            role: Role.host,
            stoneColor: StoneColor.white
        )
        identityHandler(<- identity)

        let composition: @GomokuComposition.Composition <- GomokuComposition.createComposition(
            id: index,
            host: host,
            boardSize: 15,
            totalRound: 2)

        emit HostOpeningBet(balance: betBalance)

        return <- composition
    }

    pub fun matchOpponent(
        index: UInt32,
        challenger: Address,
        bet: @FlowToken.Vault,
        recycleBetVaultRef: &FlowToken.Vault{FungibleToken.Receiver}
    ): @GomokuIdentity.IdentityToken? {
        if let matchedHost = MatchContract.match(index: index, challengerAddress: challenger) {
            assert(matchedHost != challenger, message: "You can't play with yourself.")
            let publicCapability = getAccount(matchedHost).getCapability(self.CompositionCollectionPublicPath)
            if let compositionRef = publicCapability.borrow<&Gomoku.Composition{Gomoku.PublicCompositioning}>() {
                let hostBet = self.hostOpeningBetMap[index]?.balance ?? UFix64(0)
                assert(hostBet == bet.balance, message: "Opening bets not equal.")
                self.challengerOpeningBetMap[index] <-! bet
                self.hostRaisedBetMap[index] <-! FlowToken.createEmptyVault() as! @FlowToken.Vault
                self.challengerRaisedBetMap[index] <-! FlowToken.createEmptyVault() as! @FlowToken.Vault

                let identityToken <- compositionRef.match(challenger: challenger)

                emit CompositionMatched(
                    host: matchedHost,
                    challenger: challenger,
                    currency: Type<FlowToken>().identifier,
                    openingBet: self.getOpeningBet(by: index))

                return <- identityToken
            } else {
                recycleBetVaultRef.deposit(from: <- bet)
                return nil
            }
        } else {
            recycleBetVaultRef.deposit(from: <- bet)
            return nil
        }
    }

    priv fun recycleBets() {

        let capability = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let flowReceiverReference = capability.borrow() ?? panic("Could not borrow a reference to the Flow token receiver capability")

        for key in self.hostOpeningBetMap.keys {
            var hostOpeningBet: @FlowToken.Vault? <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.hostOpeningBetMap[key] <-> hostOpeningBet
            flowReceiverReference.deposit(from: <- hostOpeningBet!)
            let emptyVault <- self.hostOpeningBetMap.remove(key: key)
            destroy emptyVault
        }

        for key in self.challengerOpeningBetMap.keys {
            var challengerOpeningBet: @FlowToken.Vault? <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.challengerOpeningBetMap[key] <-> challengerOpeningBet
            flowReceiverReference.deposit(from: <- challengerOpeningBet!)
            let emptyVault <- self.challengerOpeningBetMap.remove(key: key)
            destroy emptyVault
        }

        for key in self.hostRaisedBetMap.keys {
            var hostRaisedBet: @FlowToken.Vault? <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.hostRaisedBetMap[key] <-> hostRaisedBet
            flowReceiverReference.deposit(from: <- hostRaisedBet!)
            let emptyVault <- self.hostRaisedBetMap.remove(key: key)
            destroy emptyVault
        }

        for key in self.challengerRaisedBetMap.keys {
            var challengerRaisedBet: @FlowToken.Vault? <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.challengerRaisedBetMap[key] <-> challengerRaisedBet
            flowReceiverReference.deposit(from: <- challengerRaisedBet!)
            let emptyVault <- self.challengerRaisedBetMap.remove(key: key)
            destroy emptyVault
        }
    }

    pub enum Role: UInt8 {
        pub case host
        pub case challenger
    }

}