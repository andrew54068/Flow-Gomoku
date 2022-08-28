import MatchContract from "./MatchContract.cdc"
import FungibleToken from "./FungibleToken.cdc"
// import FlowToken from 0x0ae53cb6e3f42a79
import FlowToken from "./FlowToken.cdc"

import GomokuIdentifying from "./GomokuIdentifying.cdc"
import GomokuIdentity from "./GomokuIdentity.cdc"
import GomokuResulting from "./GomokuResulting.cdc"
import GomokuResult from "./GomokuResult.cdc"
// import Gomokuing from "./Gomokuing.cdc"
import GomokuType from "./GomokuType.cdc"

pub contract Gomoku {

    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Bets
    access(account) let hostOpeningBetMap: @{ UInt32: FlowToken.Vault }
    access(account) let challengerOpeningBetMap: @{ UInt32: FlowToken.Vault }

    access(account) let hostRaisedBetMap: @{ UInt32: FlowToken.Vault }
    access(account) let challengerRaisedBetMap: @{ UInt32: FlowToken.Vault }

    // Events
    // Event be emitted when the composition is created
    pub event HostOpeningBet(balance: UFix64)

    // Event be emitted when the contract is created
    pub event CompositionMatched(
        host: Address,
        challenger: Address,
        currency: String,
        openingBet: UFix64)

    pub event CompositionCreated(
        host: Address,
        currency: String)
    pub event CollectionCreated()
    pub event Withdraw(id: UInt32, from: Address?)
    pub event Deposit(id: UInt32, to: Address?)

    pub event CollectionNotFound(type: Type, path: Path, address: Address)
    pub event ResourceNotFound(id: UInt32, type: Type, address: Address)

    pub event makeMove(
        locationX: Int8,
        locationY: Int8,
        stoneColor: UInt8)

    init() {
        self.CollectionStoragePath = /storage/gomokuCompositionCollection
        self.CollectionPublicPath = /public/gomokuCompositionCollection

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
    pub fun getCompositionRef(by index: UInt32): &Gomoku.Composition? {
        if let host = MatchContract.getHostAddress(by: index) {
            if let collectionRef = getAccount(host)
                .getCapability<&Gomoku.CompositionCollection>(self.CollectionPublicPath)
                .borrow() {
                return collectionRef.borrow(id: index)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    pub fun getParticipants(by index: UInt32): [Address] {
        return self.getCompositionRef(by: index)?.getParticipants() ?? []
    }

    // Opening bets
    pub fun getOpeningBet(by index: UInt32): UFix64? {
        let hostBet = self.hostOpeningBetMap[index]?.balance
        if hostBet == nil {
            return nil
        }
        let challengerBet = self.challengerOpeningBetMap[index]?.balance
        if challengerBet == nil {
            return hostBet!
        }
        return hostBet! + challengerBet!
    }

    // Opening bets + raised bets
    pub fun getValidBets(by index: UInt32): UFix64? {
        let openingBet = self.getOpeningBet(by: index)
        if let bet = openingBet {
            let hostRaisedBet = self.hostRaisedBetMap[index]?.balance ?? UFix64(0)
            let challengerRaisedBet = self.challengerRaisedBetMap[index]?.balance ?? UFix64(0)
            if hostRaisedBet >= challengerRaisedBet {
                return bet + (challengerRaisedBet * UFix64(2))
            } else {
                return bet + (hostRaisedBet * UFix64(2))
            }
        }
        return nil
    }

    // Transaction
    pub fun register(
        host: Address,
        openingBet: @FlowToken.Vault,
        identityCollectionRef: &GomokuIdentity.IdentityCollection,
        compositionCollectionRef: &Gomoku.CompositionCollection
    ) {
        let index = MatchContract.register(host: host)

        let betBalance: UFix64 = openingBet.balance
        if self.hostOpeningBetMap.keys.contains(index) {
            let balance = self.hostOpeningBetMap[index]?.balance ?? UFix64(0)
            assert(balance == UFix64(0), message: "Already registered.")

            var tempVault: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

            tempVault.deposit(from: <- openingBet)

            let empty <- self.hostOpeningBetMap[index] <- tempVault
            destroy empty
        } else {
            self.hostOpeningBetMap[index] <-! openingBet
        }

        let identity <- GomokuIdentity.createIdentity(
            id: index,
            address: host,
            role: GomokuType.Role.host,
            stoneColor: GomokuType.StoneColor.white
        )
        identityCollectionRef.deposit(token: <- identity)

        let composition <- Gomoku.createComposition(
            id: index,
            host: host,
            boardSize: 15,
            totalRound: 2)

        emit HostOpeningBet(balance: betBalance)

        compositionCollectionRef.deposit(token: <- composition)
    }

    pub fun matchOpponent(
        index: UInt32,
        challenger: Address,
        bet: @FlowToken.Vault,
        recycleBetVaultRef: &FlowToken.Vault{FungibleToken.Receiver},
        identityCollectionRef: &GomokuIdentity.IdentityCollection
    ): Bool {
        if let matchedHost = MatchContract.match(index: index, challengerAddress: challenger) {
            assert(matchedHost != challenger, message: "You can't play with yourself.")

            if let compositionCollectionRef = getAccount(matchedHost)
                .getCapability<&Gomoku.CompositionCollection>(self.CollectionPublicPath)
                .borrow() {

                let hostBet = self.hostOpeningBetMap[index]?.balance ?? UFix64(0)
                assert(hostBet == bet.balance, message: "Opening bets not equal.")
                self.hostRaisedBetMap[index] <-! FlowToken.createEmptyVault() as! @FlowToken.Vault
                self.challengerRaisedBetMap[index] <-! FlowToken.createEmptyVault() as! @FlowToken.Vault

                if let compositionRef = compositionCollectionRef.borrow(id: index) {
                    self.challengerOpeningBetMap[index] <-! bet

                    compositionRef.match(
                        identityCollectionRef: identityCollectionRef,
                        challenger: challenger)

                    emit CompositionMatched(
                        host: matchedHost,
                        challenger: challenger,
                        currency: Type<FlowToken>().identifier,
                        openingBet: self.getOpeningBet(by: index) ?? UFix64(0))
                    return true
                } else {
                    recycleBetVaultRef.deposit(from: <- bet)
                    return false
                }
            } else {
                recycleBetVaultRef.deposit(from: <- bet)
                return false
            }
        } else {
            recycleBetVaultRef.deposit(from: <- bet)
            return false
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

    pub resource Composition {

        pub let id: UInt32

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: UInt8

        // timeout of block height
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

        priv var winner: GomokuType.Role?

        priv var host: Address
        priv var challenger: Address?
        priv var roundWiners: [GomokuType.Role]
        priv var steps: @[[Stone]]
        priv var locationStoneMap: {String: GomokuType.StoneColor}

        init(
            id: UInt32,
            host: Address,
            boardSize: UInt8,
            totalRound: UInt8
        ) {
            pre {
                totalRound >= 2: "Total round should be 2 to take turns to make first move (black stone) for fairness."
                totalRound % 2 == 0: "Total round should be event number to take turns to make first move (black stone) for fairness."
            }

            self.id = id
            self.host = host
            self.boardSize = boardSize
            self.challenger = nil
            self.totalRound = totalRound
            self.currentRound = 0
            self.winner = nil
            self.roundWiners = []
            self.steps <- []
            self.locationStoneMap = {}

            self.latestBlockHeight = getCurrentBlock().height
            self.blockHeightTimeout = UInt64(60 * 60 * 24 * 7)

            emit CompositionCreated(
                host: host,
                currency: Type<FlowToken>().identifier)
        }

        // Script
        pub fun getTimeout(): UInt64 {
            return self.latestBlockHeight + self.blockHeightTimeout
        }

        pub fun getStoneData(for round: UInt8): [StoneData] {
            pre {
                self.steps.length > Int(round): "Round ".concat(round.toString()).concat(" not exist.")
            }
            var placeholderArray: @[Stone] <- []
            self.steps[self.currentRound] <-> placeholderArray
            var placeholderStone <- create Stone(
                color: GomokuType.StoneColor.black,
                location: GomokuType.StoneLocation(x: 0, y: 0)
            )
            var stoneData: [StoneData] = []
            var index = 0
            while index < placeholderArray.length {
                placeholderArray[index] <-> placeholderStone
                stoneData.append(placeholderStone.convertToData() as! StoneData)
                placeholderArray[index] <-> placeholderStone
                // destroy step
                index = index + 1
            }

            self.steps[self.currentRound] <-> placeholderArray

            destroy placeholderArray
            destroy placeholderStone
            return stoneData
        }

        pub fun getParticipants(): [Address] {
            if let challenger = self.challenger {
                return [self.host, challenger]
            } else {
                return [self.host]
            }
        }

        // Transaction
        pub fun makeMove(
            identityCollectionRef: &GomokuIdentity.IdentityCollection,
            location: GomokuType.StoneLocation,
            raisedBet: @FlowToken.Vault
        ) {

            // check identity
            let identityTokenRef = identityCollectionRef.borrow(id: self.id) as &GomokuIdentity.IdentityToken?
            assert(identityTokenRef != nil, message: "Identity token ref not found.")
            assert(identityTokenRef?.owner?.address == identityTokenRef?.address, message: "Identity token should not be transfer to other.")

            let identityToken <- identityCollectionRef.withdraw(by: self.id) ?? panic("You are not suppose to make this move.")
            assert(Int(self.currentRound) + 1 > self.roundWiners.length, message: "Game Over.")

            let stone <- create Stone(
                color: identityToken.stoneColor,
                location: location
            )

            // check raise bet type
            assert(
                raisedBet.getType() == Type<@FlowToken.Vault>(),
                message: "You can onlty raise bet with the same token of opening bet: "
                    .concat(raisedBet.getType().identifier)
            )

            let currentRole = self.getRole()
            // var currentRole = GomokuType.Role.host
            // switch currentRole {
            // case GomokuType.Role.host:
            //     // currentRole = GomokuType.Role.challenger
            // case GomokuType.Role.challenger:
            //     // currentRole = GomokuType.Role.host
            // default:
            //     panic("Should not be the case.")
            // }

            switch currentRole {
            case GomokuType.Role.host:
                assert(identityToken.address == self.host, message: "It's not you turn yet!")
                var emptyBet: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                var hostRaisedBet <- Gomoku.hostRaisedBetMap[self.id] <- emptyBet
                if let oldBet <- hostRaisedBet {
                    oldBet.deposit(from: <- raisedBet)
                    let empty <- Gomoku.hostRaisedBetMap[self.id] <- oldBet
                    destroy empty
                } else {
                    let empty <- Gomoku.hostRaisedBetMap[self.id] <- raisedBet
                    destroy empty
                    destroy hostRaisedBet
                }
            case GomokuType.Role.challenger:
                assert(self.challenger != nil, message: "Challenger not found.")
                assert(identityToken.address == self.challenger!, message: "It's not you turn yet!")
                var emptyBet: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                var hostRaisedBet <- Gomoku.challengerRaisedBetMap[self.id] <- emptyBet
                if let oldBet <- hostRaisedBet {
                    oldBet.deposit(from: <- raisedBet)
                    let empty <- Gomoku.challengerRaisedBetMap[self.id] <- oldBet
                    destroy empty
                } else {
                    let empty <- Gomoku.challengerRaisedBetMap[self.id] <- raisedBet
                    destroy empty
                    destroy hostRaisedBet
                }
            default:
                panic("Should not be the case.")
            }

            let stoneRef = &stone as &Stone

            // validate move
            self.verifyAndStoreStone(stone: <- stone)

            // reset timeout
            self.latestBlockHeight = getCurrentBlock().height

            emit makeMove(
                locationX: stoneRef.location.x,
                locationY: stoneRef.location.y,
                stoneColor: stoneRef.color.rawValue)

            let hasRoundWinner = self.checkWinnerInAllDirection(
                targetColor: stoneRef.color,
                center: stoneRef.location)
            if hasRoundWinner {
                self.roundWiners.append(identityToken.role)
                // event
                // end of current round
                if self.currentRound + UInt8(1) < self.totalRound {
                    self.switchRound()
                } else {
                    // end of game
                    self.finalize(identityToken: <- identityToken)
                    return
                }
            }
            identityCollectionRef.deposit(token: <- identityToken)
        }

        pub fun surrender(
            identityToken: @GomokuIdentity.IdentityToken
        ): @GomokuIdentity.IdentityToken? {
            pre {
                identityToken.id == self.id: "You are not authorized to make this move."
            }
            switch identityToken.role {
            case GomokuType.Role.host:
                self.roundWiners[self.currentRound] = GomokuType.Role.challenger
            case GomokuType.Role.challenger:
                self.roundWiners[self.currentRound] = GomokuType.Role.host
            default:
                panic("Should not be the case.")
            }
            if self.currentRound + 1 < self.totalRound {
                // switch to next round
                self.switchRound()
                return <- identityToken
            } else {
                // final round
                self.finalize(identityToken: <- identityToken)
                return nil
            }
        }

        // Can only match by Gomoku.cdc to prevent from potential attack.
        access(account) fun match(
            identityCollectionRef: &GomokuIdentity.IdentityCollection,
            challenger: Address
        ) {
            pre {
                self.challenger == nil: "Already matched."
            }
            self.challenger = challenger

            // generate identity token to identify who take what stone in case someone takes other's move.
            let identity <- GomokuIdentity.createIdentity(
                id: self.id,
                address: challenger,
                role: GomokuType.Role.challenger,
                stoneColor: GomokuType.StoneColor.black
            )
            identityCollectionRef.deposit(token: <- identity)
        }

        // Restricted to prevent from potential attack.
        access(account) fun finalizeByTimeout(
            identityToken: @GomokuIdentity.IdentityToken
        ): @GomokuIdentity.IdentityToken? {
            pre {
                getCurrentBlock().height > self.getTimeout(): "Let's give opponent more time to think......"
            }

            let lastRole = self.getRole()
            self.roundWiners.append(lastRole)
            if self.currentRound + UInt8(1) < self.totalRound {
                self.switchRound()
                return <- identityToken
            } else {
                // end of game
                // distribute reward
                self.finalize(identityToken: <- identityToken)
                return nil
            }
        }

        // Private Method
        priv fun finalize(identityToken: @GomokuIdentity.IdentityToken) {
            pre {
                self.roundWiners.length == Int(self.totalRound): "Game not over yet!"
                self.challenger != nil: "Challenger not found."
                Gomoku.hostOpeningBetMap.keys.contains(identityToken.id): "Host's OpeningBet not found."
                Gomoku.challengerOpeningBetMap.keys.contains(identityToken.id): "Challenger's OpeningBet not found."
                Gomoku.hostRaisedBetMap.keys.contains(identityToken.id): "Host's RaisedBet not found."
                Gomoku.challengerRaisedBetMap.keys.contains(identityToken.id): "Challenger's RaisedBet not found."
            }

            // Flow Receiver
            let devFlowTokenReceiver = Gomoku.account
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow() ?? panic("Could not borrow a reference to the dev flowTokenReceiver capability.")

            let hostFlowTokenReceiver = getAccount(self.host)
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow() ?? panic("Could not borrow a reference to the dev flowTokenReceiver capability.")

            let challengerFlowTokenReceiver = getAccount(self.challenger!)
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow() ?? panic("Could not borrow a reference to the dev flowTokenReceiver capability.")

            // withdraw reward
            let tatalVault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let hostOpeningBet: @FlowToken.Vault? <- Gomoku.hostOpeningBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            if let hostBet <- hostOpeningBet {
                tatalVault.deposit(from: <- hostBet)
            } else {
                destroy hostOpeningBet
            }
            let challengerOpeningBet: @FlowToken.Vault? <- Gomoku.challengerOpeningBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            if let challengerBet <- challengerOpeningBet {
                tatalVault.deposit(from: <- challengerBet)
            } else {
                destroy challengerOpeningBet
            }
            destroy Gomoku.hostOpeningBetMap.remove(key: identityToken.id)
            destroy Gomoku.challengerOpeningBetMap.remove(key: identityToken.id)

            let hostRaisedBet: @FlowToken.Vault? <- Gomoku.hostRaisedBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let challengerRaisedBet: @FlowToken.Vault? <- Gomoku.challengerRaisedBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            if let hostBet <- hostRaisedBet {
                if let challengerBet <- challengerRaisedBet {
                    if hostBet.balance == challengerBet.balance {
                        tatalVault.deposit(from: <- hostBet)
                        tatalVault.deposit(from: <- challengerBet)
                    } else if hostBet.balance > challengerBet.balance {
                        let backToHost <- hostBet.withdraw(amount: hostBet.balance - challengerBet.balance)
                        hostFlowTokenReceiver.deposit(from: <- backToHost)
                        tatalVault.deposit(from: <- hostBet)
                        tatalVault.deposit(from: <- challengerBet)
                    } else {
                        let backToChallenger <- challengerBet.withdraw(amount: challengerBet.balance - hostBet.balance)
                        challengerFlowTokenReceiver.deposit(from: <- backToChallenger)
                        tatalVault.deposit(from: <- hostBet)
                        tatalVault.deposit(from: <- challengerBet)
                    }
                } else {
                    hostFlowTokenReceiver.deposit(from: <- hostBet)
                    destroy challengerRaisedBet
                }
            } else {
                if let challengerBet <- challengerRaisedBet {
                    challengerFlowTokenReceiver.deposit(from: <- challengerBet)
                } else {
                    destroy challengerRaisedBet
                }
                destroy hostRaisedBet
            }

            let totalReward = tatalVault.balance
            destroy Gomoku.hostRaisedBetMap.remove(key: identityToken.id)
            destroy Gomoku.challengerRaisedBetMap.remove(key: identityToken.id)

            let devReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let hostReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let challengerReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let winnerReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let losserReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let result = self.getWinnerResult()
            switch result {
            case GomokuType.Result.hostWins:
                // developer get 5% for developing this game
                // host get extra 1% for being host.
                // winner get 94%
                let devRewardBalance = tatalVault.balance * UFix64(5) / UFix64(100)
                let hostRewardBalance = tatalVault.balance * UFix64(1) / UFix64(100)
                let winnerRewardBalance = tatalVault.balance - devRewardBalance - hostRewardBalance
                devReward.deposit(from: <- tatalVault.withdraw(amount: devRewardBalance))
                hostReward.deposit(from: <- tatalVault.withdraw(amount: hostRewardBalance))
                winnerReward.deposit(from: <- tatalVault.withdraw(amount: winnerRewardBalance))
                destroy tatalVault
            case GomokuType.Result.challengerWins:
                // developer get 5% for developing this game
                // host get extra 1% for being host.
                // winner get 94%.
                let devRewardBalance = tatalVault.balance * UFix64(5) / UFix64(100)
                let winnerRewardBalance = tatalVault.balance - devRewardBalance
                devReward.deposit(from: <- tatalVault.withdraw(amount: devRewardBalance))
                winnerReward.deposit(from: <- tatalVault.withdraw(amount: winnerRewardBalance))
                destroy tatalVault
            case GomokuType.Result.draw:
                // draw
                // developer get 2% for developing this game
                // each player get 49%.
                let hostRewardBalance = tatalVault.balance * UFix64(49) / UFix64(100)
                let challengerRewardBalance = tatalVault.balance * UFix64(49) / UFix64(100)
                let devRewardBalance = tatalVault.balance - hostRewardBalance - challengerRewardBalance
                devReward.deposit(from: <- tatalVault.withdraw(amount: devRewardBalance))
                hostReward.deposit(from: <- tatalVault.withdraw(amount: hostRewardBalance))
                challengerReward.deposit(from: <- tatalVault.withdraw(amount: challengerRewardBalance))
                destroy tatalVault
            default:
                panic("Should not be the case.")
            }

            devFlowTokenReceiver.deposit(from: <- devReward)

            // Identity collection check
            let identityTokenId = identityToken.id

            if identityToken.address == self.host {
                if let identityCollectionRef = getAccount(self.challenger!)
                    .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                    .borrow() {
                    if let challengerIdentityToken <- identityCollectionRef.withdraw(by: identityTokenId) {
                        destroy challengerIdentityToken
                    } else {
                        emit ResourceNotFound(
                            id: identityTokenId,
                            type: Type<@GomokuIdentity.IdentityToken>(),
                            address: self.challenger!)
                    }
                } else {
                    emit CollectionNotFound(
                        type: Type<@GomokuIdentity.IdentityCollection>(),
                        path: GomokuIdentity.CollectionPublicPath,
                        address: self.challenger!)
                }
            } else if identityToken.address == self.challenger {
                if let identityCollectionRef = getAccount(self.host)
                    .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                    .borrow() {
                    if let hostIdentityToken <- identityCollectionRef.withdraw(by: identityTokenId) {
                        destroy hostIdentityToken
                    } else {
                        emit ResourceNotFound(
                            id: identityTokenId,
                            type: Type<@GomokuIdentity.IdentityToken>(),
                            address: self.host)
                    }
                } else {
                    emit CollectionNotFound(
                        type: Type<@GomokuIdentity.IdentityCollection>(),
                        path: GomokuIdentity.CollectionPublicPath,
                        address: self.host)
                }
            }
            destroy identityToken

            self.mintCompositionResults(
                id: identityTokenId,
                totalReward: totalReward,
                winnerReward: winnerReward.balance,
                hostReward: hostReward.balance,
                challengerReward: challengerReward.balance
            )

            switch result {
            case GomokuType.Result.hostWins:
                hostFlowTokenReceiver.deposit(from: <- winnerReward)
                challengerFlowTokenReceiver.deposit(from: <- losserReward)
            case GomokuType.Result.challengerWins:
                hostFlowTokenReceiver.deposit(from: <- losserReward)
                challengerFlowTokenReceiver.deposit(from: <- winnerReward)
            case GomokuType.Result.draw:
                destroy winnerReward
                destroy losserReward
            default:
                panic("Should not be the case.")
            }

            hostFlowTokenReceiver.deposit(from: <- hostReward)
            challengerFlowTokenReceiver.deposit(from: <- challengerReward)
        }

        priv fun mintCompositionResults(
            id: UInt32,
            totalReward: UFix64,
            winnerReward: UFix64,
            hostReward: UFix64,
            challengerReward: UFix64
        ) {
            pre {
                self.challenger != nil: "Challenger not found."
            }

            // get steps data
            var steps: [[StoneData]] = []
            var index: UInt8 = 0
            while index < self.totalRound {
                steps.append(self.getStoneData(for: index))
                index = index + UInt8(1)
            }

            let winnerResultCollection <- GomokuResult.createEmptyVault()
            let losserResultCollection <- GomokuResult.createEmptyVault()
            var winnerAddress: Address = self.host
            var losserAddress: Address = self.host
            let result = self.getWinnerResult()
            switch result {
            case GomokuType.Result.hostWins:
                winnerAddress = self.host
                losserAddress = self.challenger!

                let winnerResultToken <- GomokuResult.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: Fix64(winnerReward + hostReward),
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- winnerResultToken)

                let losserResultToken <- GomokuResult.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: -Fix64(totalReward / UFix64(2)),
                    steps: steps
                )
                losserResultCollection.deposit(token: <- losserResultToken)
            case GomokuType.Result.challengerWins:
                winnerAddress = self.challenger!
                losserAddress = self.host

                let winnerResultToken <- GomokuResult.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: Fix64(winnerReward + challengerReward),
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- winnerResultToken)

                let losserResultToken <- GomokuResult.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: -Fix64(totalReward / UFix64(2)) + Fix64(hostReward),
                    steps: steps
                )
                losserResultCollection.deposit(token: <- losserResultToken)
            case GomokuType.Result.draw:
                winnerAddress = self.host
                losserAddress = self.challenger!

                let drawResultToken1 <- GomokuResult.createResult(
                    id: id,
                    winner: nil,
                    losser: nil,
                    gain: Fix64(0),
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- drawResultToken1)

                let drawResultToken2 <- GomokuResult.createResult(
                    id: id,
                    winner: nil,
                    losser: nil,
                    gain: Fix64(0),
                    steps: steps
                )
                losserResultCollection.deposit(token: <- drawResultToken2)
            default:
                panic("Should not be the case.")
            }

            let winnerResultToken <- winnerResultCollection.withdraw(by: id)!
            let losserResultToken <- losserResultCollection.withdraw(by: id)!

            if let winnerResultCollectionCapability = getAccount(winnerAddress)
                .getCapability<&GomokuResult.ResultCollection>(GomokuResult.CollectionPublicPath)
                .borrow() {
                winnerResultCollectionCapability.deposit(token: <- winnerResultToken)
            } else {
                winnerResultToken.setDestroyable(true)
                destroy winnerResultToken
            }
            
            if let losserResultCollectionCapability = getAccount(losserAddress)
                .getCapability<&GomokuResult.ResultCollection>(GomokuResult.CollectionPublicPath)
                .borrow() {
                losserResultCollectionCapability.deposit(token: <- losserResultToken)
            } else {
                losserResultToken.setDestroyable(true)
                destroy losserResultToken
            }

            destroy winnerResultCollection
            destroy losserResultCollection
        }

        // Challenger go first in first round
        priv fun getRole(): GomokuType.Role {
            if self.currentRound % 2 == 0 {
                // first move is challenger if index is even
                if self.steps.length % 2 == 0 {
                    // step for challenger
                    return GomokuType.Role.challenger
                } else {
                    // step for host
                    return GomokuType.Role.host
                }
            } else {
                // first move is host if index is odd
                if self.steps.length % 2 == 0 {
                    // step for host
                    return GomokuType.Role.host
                } else {
                    // step for challenger
                    return GomokuType.Role.challenger
                }
            }
        }

        priv fun switchRound() {
            pre {
                self.roundWiners[self.currentRound] != nil: "Current round winner not decided."
                self.totalRound > self.currentRound + 1: "Next round should not over totalRound."
            }
            post {
                self.currentRound == before(self.currentRound) + 1: "fatal error."
                self.roundWiners[self.currentRound] == nil: "Should not have winner right after switching rounds."
            }
            self.currentRound = self.currentRound + 1

            let hostIdentityCollectionCapability = getAccount(self.host)
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the host capability.")
            if let identityToken = hostIdentityCollectionCapability.borrow(id: self.id) {
                identityToken.switchIdentity()
            } else {
                panic("Could not borrow a reference to identityToken.")
            }

            assert(self.challenger != nil, message: "Challenger not found.")

            let challengerIdentityCollectionCapability = getAccount(self.challenger!)
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the challenger capability.")
            if let identityToken = challengerIdentityCollectionCapability.borrow(id: self.id) {
                identityToken.switchIdentity()
            } else {
                panic("Could not borrow a reference to identityToken.")
            }
        }

        priv fun verifyAndStoreStone(stone: @Stone) {
            pre {
                // self.steps.length == 2: "Steps length should be 2."
                Int(self.currentRound) <= 1: "Composition only has 2 round each."
            }
            if self.steps.length < Int(self.currentRound) + 1 {
                self.steps.append(<- [])
            }
            let roundSteps = &self.steps[self.currentRound] as &[AnyResource{GomokuType.Stoning}]

            // check stone location is within board.
            let isOnBoard = self.verifyOnBoard(location: stone.location)
            assert(
                isOnBoard,
                message: "Stone location"
                    .concat(stone.location.description())
                    .concat(" is invalid."))

            // check location not yet taken.
            assert(self.locationStoneMap[stone.key()] == nil, message: "This place had been taken.")

            if roundSteps.length % 2 == 0 {
                // black stone move
                assert(stone.color == GomokuType.StoneColor.black, message: "It should be black side's turn.")
            } else {
                // white stone move
                assert(stone.color == GomokuType.StoneColor.white, message: "It should be white side's turn.")
            }

            let stoneColor = stone.color
            let stoneLocation = stone.location
            self.locationStoneMap[stone.key()] = stoneColor
            self.steps[self.currentRound].append(<- stone)
        }

        priv fun verifyOnBoard(location: GomokuType.StoneLocation): Bool {
            if location.x > Int8(self.boardSize) - Int8(1) {
                return false
            }
            if location.x < Int8(0) {
                return false
            }
            if location.y > Int8(self.boardSize) - Int8(1) {
                return false
            }
            if location.y < Int8(0) {
                return false
            }
            return true
        }

        priv fun checkWinnerInAllDirection(
            targetColor: GomokuType.StoneColor,
            center: GomokuType.StoneLocation
        ): Bool {
            return self.checkWinner(
                    targetColor: targetColor,
                    center: center,
                    direction: GomokuType.VerifyDirection.vertical)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: GomokuType.VerifyDirection.horizontal)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: GomokuType.VerifyDirection.diagonal)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: GomokuType.VerifyDirection.reversedDiagonal)
        }

        priv fun checkWinner(
            targetColor: GomokuType.StoneColor,
            center: GomokuType.StoneLocation,
            direction: GomokuType.VerifyDirection
        ): Bool {
            var countInRow: UInt8 = 1
            var shift: Int8 = 1
            var isFinished: Bool = false
            switch direction {
            case GomokuType.VerifyDirection.vertical:
                while !isFinished
                        && shift <= Int8(4)
                        && center.x - shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x - shift, y: center.y)
                    if let color = self.locationStoneMap[currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
                shift = 1
                isFinished = false
                while !isFinished
                        && shift <= Int8(4)
                        && center.x + shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x + shift, y: center.y)
                    if let color = self.locationStoneMap[currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
            case GomokuType.VerifyDirection.horizontal:
                while !isFinished
                        && shift <= Int8(4)
                        && center.y - shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x, y: center.y - shift)
                    if let color = self.locationStoneMap[currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
                shift = 1
                isFinished = false
                while !isFinished
                        && shift <= Int8(4)
                        && center.y + shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x, y: center.y + shift)
                    if let color = self.locationStoneMap[currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
            case GomokuType.VerifyDirection.diagonal:
                while !isFinished
                        && shift <= Int8(4)
                        && center.x - shift >= Int8(0)
                        && center.y - shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x - shift, y: center.y - shift)
                    if let color = self.locationStoneMap[currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
                shift = 1
                isFinished = false
                while !isFinished
                        && shift <= Int8(4)
                        && center.x + shift >= Int8(0)
                        && center.y + shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x + shift, y: center.y + shift)
                    if let color = self.locationStoneMap[currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
            case GomokuType.VerifyDirection.reversedDiagonal:
                while !isFinished
                        && shift <= Int8(4)
                        && center.x - shift >= Int8(0)
                        && center.y + shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x - shift, y: center.y + shift)
                    if let color = self.locationStoneMap[currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
                shift = 1
                isFinished = false
                while !isFinished
                        && shift <= Int8(4)
                        && center.x + shift >= Int8(0)
                        && center.y - shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x + shift, y: center.y - shift)
                    if let color = self.locationStoneMap[currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
            }
            return countInRow >= UInt8(5)
        }

        priv fun getWinnerResult(): GomokuType.Result {
            pre {
                self.roundWiners.length == Int(self.totalRound): "Game not over yet!"
            }

            let firstRoundWinner = self.roundWiners[0]
            let secondRoundWinner = self.roundWiners[1]
            if firstRoundWinner == secondRoundWinner {
                let winner = firstRoundWinner
                // has winner
                switch winner {
                case GomokuType.Role.host:
                    return GomokuType.Result.hostWins
                case GomokuType.Role.challenger:
                    return GomokuType.Result.challengerWins
                default:
                    panic("Should not be the case.")
                }
                return GomokuType.Result.draw
            } else {
                return GomokuType.Result.draw
            }
        }

        destroy() {
            destroy self.steps
        }

    }

    access(account) fun createComposition(
        id: UInt32,
        host: Address,
        boardSize: UInt8,
        totalRound: UInt8
    ): @Gomoku.Composition {

        let Composition <- create Composition(
            id: id,
            host: host,
            boardSize: boardSize,
            totalRound: totalRound
        )

        return <- Composition
    }

    pub resource CompositionCollection {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        priv var ownedCompositionMap: @{UInt32: Gomoku.Composition}
        priv var destroyable: Bool

        init () {
            self.ownedCompositionMap <- {}
            self.destroyable = false
            self.StoragePath = /storage/gomokuCollection
            self.PublicPath = /public/gomokuCollection
        }

        access(account) fun withdraw(by id: UInt32): @Gomoku.Composition {
            let token <- self.ownedCompositionMap.remove(key: id) ?? panic("missing Composition")
            emit Withdraw(id: token.id, from: self.owner?.address)
            if self.ownedCompositionMap.keys.length == 0 {
                self.destroyable = true
            }
            return <- token
        }

        access(account) fun deposit(token: @Gomoku.Composition) {
            let token <- token
            let id: UInt32 = token.id
            let oldToken <- self.ownedCompositionMap[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            self.destroyable = false
            destroy oldToken
        }

        pub fun getIds(): [UInt32] {
            return self.ownedCompositionMap.keys
        }

        pub fun getBalance(): Int {
            return self.ownedCompositionMap.keys.length
        }

        pub fun borrow(id: UInt32): &Gomoku.Composition? {
            return &self.ownedCompositionMap[id] as &Gomoku.Composition?
        }

        destroy() {
            destroy self.ownedCompositionMap
            if self.destroyable == false {
                panic("Ha Ha! Got you! You can't destory this collection if there are Gomoku Composition!")
            }
        }
    }

    pub fun createEmptyVault(): @Gomoku.CompositionCollection {
        emit CollectionCreated()
        return <- create CompositionCollection()
    }

    pub struct StoneData: GomokuType.StoneDataing {
        pub let color: GomokuType.StoneColor
        pub let location: GomokuType.StoneLocation

        init(
            color: GomokuType.StoneColor,
            location: GomokuType.StoneLocation
        ) {
            self.color = color
            self.location = location
        }
    }

    pub resource Stone: GomokuType.Stoning {
        pub let color: GomokuType.StoneColor
        pub let location: GomokuType.StoneLocation

        pub init(
            color: GomokuType.StoneColor,
            location: GomokuType.StoneLocation
        ) {
            self.color = color
            self.location = location
        }

        pub fun key(): String {
            return self.location.key()
        }

        pub fun convertToData(): AnyStruct{GomokuType.StoneDataing} {
            return StoneData(
                color: self.color,
                location: self.location
            )
        }
    }
}