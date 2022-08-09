import FlowToken from "./FlowToken.cdc"
import Gomokuing from "./Gomokuing.cdc"
import GomokuCompositioning from "./GomokuCompositioning.cdc"
import GomokuResulting from "./GomokuResulting.cdc"
import GomokuType from "./GomokuType.cdc"

pub contract GomokuComposition: GomokuCompositioning {

    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Events
    pub event CompositionCreated(
        host: Address,
        currency: String)
    pub event CollectionCreated()
    pub event Withdraw(id: UInt32, from: Address?)
    pub event Deposit(id: UInt32, to: Address?)

    pub event CollectionNotFound(type: Type, path: Path, address: Address)
    pub event ResourceNotFound(id: UInt32, type: Type, address: Address)

    pub event makeMove(location: StoneLocation, GomokuType.StoneColor: GomokuType.StoneColor)

    init() {
        self.CollectionStoragePath = /storage/gomokuCompositionCollection
        self.CollectionPublicPath = /public/gomokuCompositionCollection
    }

    pub resource Composition: GomokuCompositioning.Compositioning {

        pub let id: UInt32

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: 

        // timeout of block height
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

        priv var winner: GomokuType.Role?

        priv var host: Address
        priv var challenger: Address?
        priv var roundWiners: [GomokuType.Role]
        priv var steps: @[[Stone]]
        priv var locationStoneMap: {String:GomokuType.StoneColor}

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
                location: StoneLocation(x: 0, y: 0)
            )
            var stoneData: [StoneData] = []
            var index = 0
            while index < placeholderArray.length {
                placeholderArray[index] <-> placeholderStone
                stoneData.append(placeholderStone.convertToData())
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
            identityToken: @AnyResource{GomokuIdentifying.IdentityTokening},
            stone: @Stone,
            raisedBet: @FlowToken.Vault,
            hasRoundWinnerCallback: ((Bool): Void)
        ): @AnyResource{GomokuIdentifying.IdentityTokening}? {
            // check identity
            pre {
                identityToken.GomokuType.StoneColor == stone.color: "You are not suppose to make this move."
                identityToken.id == self.id: "You are not authorized to make this move."
                identityToken.owner?.address == identityToken.address: "Identity token should not be transfer to other."
                Int(self.currentRound) + 1 > self.roundWiners.length: "Game Over."
            }

            // check raise bet type
            assert(
                raisedBet.getType() == Type<@FlowToken.Vault>(),
                message: "You can onlty raise bet with the same token of opening bet: "
                    .concat(raisedBet.getType().identifier)
            )

            let lastRole = self.getRole()
            var currentRole = GomokuType.Role.host
            switch lastRole {
            case GomokuType.Role.host:
                currentRole = GomokuType.Role.challenger
                assert(self.challenger != nil, message: "Challenger not found.")
                assert(identityToken.address == self.challenger!, message: "It's not you turn yet!")
            case GomokuType.Role.challenger:
                currentRole = GomokuType.Role.host
                assert(identityToken.address == self.host, message: "It's not you turn yet!")
            default:
                panic("Should not be the case.")
            }

            switch currentRole {
            case GomokuType.Role.host:
                var emptyBet: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                var hostRaisedBet <- Gomokuing.hostRaisedBetMap[self.id] <- emptyBet
                if let oldBet <- hostRaisedBet {
                    oldBet.deposit(from: <- raisedBet)
                    let empty <- Gomokuing.hostRaisedBetMap[self.id] <- oldBet
                    destroy empty
                } else {
                    let empty <- Gomokuing.hostRaisedBetMap[self.id] <- raisedBet
                    destroy empty
                    destroy hostRaisedBet
                }
            case GomokuType.Role.challenger:
                var emptyBet: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                var hostRaisedBet <- Gomokuing.challengerRaisedBetMap[self.id] <- emptyBet
                if let oldBet <- hostRaisedBet {
                    oldBet.deposit(from: <- raisedBet)
                    let empty <- Gomokuing.challengerRaisedBetMap[self.id] <- oldBet
                    destroy empty
                } else {
                    let empty <- Gomokuing.challengerRaisedBetMap[self.id] <- raisedBet
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

            let hasRoundWinner = self.checkWinnerInAllDirection(
                targetColor: stoneRef.color,
                center: stoneRef.location)
            if hasRoundWinner {
                self.roundWiners.append(identityToken.role)
                // event
                // end of current round
                // hasRoundWinnerCallback(hasRoundWinner)
                if self.currentRound + UInt8(1) < self.totalRound {
                    self.switchRound()
                } else {
                    // end of game
                    self.finalize(identityToken: <- identityToken)
                    return nil
                }
            }
            return <- identityToken
        }

        pub fun surrender(identityToken: @AnyResource{GomokuIdentifying.IdentityTokening}): @AnyResource{GomokuIdentifying.IdentityTokening}? {
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
            identityCollectionRef: &AnyResource{GomokuIdentifying.IdentityCollecting},
            challenger: Address
        ) {
            pre {
                self.challenger == nil: "Already matched."
            }
            self.challenger = challenger

            // generate identity token to identify who take what stone in case someone takes other's move.
            let identity <- GomokuIdentifying.createIdentity(
                id: self.id,
                address: challenger,
                role: GomokuType.Role.challenger,
                GomokuType.StoneColor: GomokuType.StoneColor.black
            )
            identityCollectionRef.deposit(token: <- identity)
        }

        // Restricted to prevent from potential attack.
        access(account) fun finalizeByTimeout(
            identityToken: @AnyResource{GomokuIdentifying.IdentityTokening}
        ): @AnyResource{GomokuIdentifying.IdentityTokening}? {
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
        priv fun finalize(identityToken: @AnyResource{GomokuIdentifying.IdentityTokening}) {
            pre {
                self.roundWiners.length == Int(self.totalRound): "Game not over yet!"
                self.challenger != nil: "Challenger not found."
                Gomokuing.hostOpeningBetMap.keys.contains(identityToken.id): "Host's OpeningBet not found."
                Gomokuing.challengerOpeningBetMap.keys.contains(identityToken.id): "Challenger's OpeningBet not found."
                Gomokuing.hostRaisedBetMap.keys.contains(identityToken.id): "Host's RaisedBet not found."
                Gomokuing.challengerRaisedBetMap.keys.contains(identityToken.id): "Challenger's RaisedBet not found."
            }

            // Flow Receiver
            let devFlowTokenReceiver = GomokuComposition.account
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
            let hostOpeningBet <- Gomokuing.hostOpeningBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let challengerOpeningBet <- Gomokuing.challengerOpeningBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            destroy Gomokuing.hostOpeningBetMap.remove(key: identityToken.id)
            destroy Gomokuing.challengerOpeningBetMap.remove(key: identityToken.id)
            tatalVault.deposit(from: <- hostOpeningBet)
            tatalVault.deposit(from: <- challengerOpeningBet)

            let hostRaisedBet <- Gomokuing.hostRaisedBetMap[identityToken.id]! <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let challengerRaisedBet <- Gomokuing.challengerRaisedBetMap[identityToken.id]! <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            if hostRaisedBet.balance == challengerRaisedBet.balance {
                tatalVault.deposit(from: <- hostRaisedBet)
                tatalVault.deposit(from: <- challengerRaisedBet)
            } else if hostRaisedBet.balance > challengerRaisedBet.balance {
                let backToHost <- hostRaisedBet.withdraw(amount: hostRaisedBet.balance - challengerRaisedBet.balance)
                hostFlowTokenReceiver.deposit(from: <- backToHost)
                tatalVault.deposit(from: <- hostRaisedBet)
                tatalVault.deposit(from: <- challengerRaisedBet)
            } else {
                let backToChallenger <- challengerRaisedBet.withdraw(amount: challengerRaisedBet.balance - hostRaisedBet.balance)
                challengerFlowTokenReceiver.deposit(from: <- backToChallenger)
                tatalVault.deposit(from: <- hostRaisedBet)
                tatalVault.deposit(from: <- challengerRaisedBet)
            }
            let totalReward = tatalVault.balance
            destroy Gomokuing.hostRaisedBetMap.remove(key: identityToken.id)
            destroy Gomokuing.challengerRaisedBetMap.remove(key: identityToken.id)

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
                    .getCapability<&GomokuIdentifying.IdentityCollection>(GomokuIdentifying.CollectionPublicPath)
                    .borrow() {
                    if let challengerIdentityToken <- identityCollectionRef.withdraw(by: identityTokenId) {
                        destroy challengerIdentityToken
                    } else {
                        emit ResourceNotFound(
                            id: identityTokenId,
                            type: Type<AnyResource{GomokuIdentifying.IdentityTokening}>(),
                            address: self.challenger!)
                    }
                } else {
                    emit CollectionNotFound(
                        type: Type<AnyResource{GomokuIdentifying.IdentityCollecting}>(),
                        path: GomokuIdentifying.CollectionPublicPath,
                        address: self.challenger!)
                }
            } else if identityToken.address == self.challenger {
                if let identityCollectionRef = getAccount(self.host)
                    .getCapability<&GomokuIdentifying.IdentityCollection>(GomokuIdentifying.CollectionPublicPath)
                    .borrow() {
                    if let hostIdentityToken <- identityCollectionRef.withdraw(by: identityTokenId) {
                        destroy hostIdentityToken
                    } else {
                        emit ResourceNotFound(
                            id: identityTokenId,
                            type: Type<AnyResource{GomokuIdentifying.IdentityTokening}>(),
                            address: self.host)
                    }
                } else {
                    emit CollectionNotFound(
                        type: Type<AnyResource{GomokuIdentifying.IdentityCollecting}>(),
                        path: GomokuIdentifying.CollectionPublicPath,
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

            let winnerResultCollection: @AnyResource{GomokuResulting.ResultCollecting} <- GomokuResulting.createEmptyVault()
            let losserResultCollection: @AnyResource{GomokuResulting.ResultCollecting} <- GomokuResulting.createEmptyVault()
            var winnerAddress: Address = self.host
            var losserAddress: Address = self.host
            let result = self.getWinnerResult()
            switch result {
            case GomokuType.Result.hostWins:
                winnerAddress = self.host
                losserAddress = self.challenger!

                let winnerResultToken <- GomokuResulting.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: winnerReward + hostReward,
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- winnerResultToken)

                let losserResultToken <- GomokuResulting.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: -Fix64(totalReward / UFix64(2)),
                    steps: steps
                )
                losserResultCollection.deposit(from: <- losserResultToken)
            case GomokuType.Result.challengerWins:
                winnerAddress = self.challenger!
                losserAddress = self.host

                let winnerResultToken <- GomokuResulting.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: winnerReward + challengerReward,
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- winnerResultToken)

                let losserResultToken <- GomokuResulting.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: -Fix64(totalReward / UFix64(2)) + Fix64(hostReward),
                    steps: steps
                )
                losserResultCollection.deposit(from: <- losserResultToken)
            case GomokuType.Result.draw:
                winnerAddress = self.host
                losserAddress = self.challenger!

                let drawResultToken1 <- GomokuResulting.createResult(
                    id: id,
                    winner: nil,
                    losser: nil,
                    gain: Fix64(0),
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- drawResultToken1)

                let drawResultToken2 <- GomokuResulting.createResult(
                    id: id,
                    winner: nil,
                    losser: nil,
                    gain: Fix64(0),
                    steps: steps
                )
                losserResultCollection.deposit(from: <- drawResultToken2)
            default:
                panic("Should not be the case.")
            }

            let winnerResultToken <-! winnerResultCollection.withdraw(by: id)
            let losserResultToken <-! losserResultCollection.withdraw(by: id)

            if let winnerResultCollectionCapability = getAccount(self.winnerAddress)
                .getCapability<&GomokuResulting.ResultCollection>(GomokuResulting.CollectionPublicPath)
                .borrow() {
                winnerResultCollectionCapability.deposit(token: <- winnerResultToken)
            } else {
                winnerResultToken.setDestroyable(true)
                destroy winnerResultToken
            }
            
            if let losserResultCollectionCapability = getAccount(self.losserAddress)
                .getCapability<&GomokuResulting.ResultCollection>(GomokuResulting.CollectionPublicPath)
                .borrow() {
                losserResultCollectionCapability.deposit(token: <- losserResultToken)
            } else {
                losserResultToken.setDestroyable(true)
                destroy losserResultToken
            }
        
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
                .getCapability<&GomokuIdentifying.IdentityCollection>(GomokuIdentifying.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the host capability.")
            hostIdentityCollectionCapability.borrow(id: self.id).switchIdentity()

            assert(self.challenger != nil, message: "Challenger not found.")

            let challengerIdentityCollectionCapability = getAccount(self.challenger!)
                .getCapability<&GomokuIdentifying.IdentityCollection>(GomokuIdentifying.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the challenger capability.")
            challengerIdentityCollectionCapability.borrow(id: self.id).switchIdentity()
        }

        priv fun verifyAndStoreStone(stone: @Stone) {
            pre {
                self.steps.length == 2: "Steps length should be 2."
                self.currentRound <= 1: "Composition only has 2 round each."
            }
            let roundSteps = &self.steps[self.currentRound] as &[Stone]

            // check stone location is within board.
            let isOnBoard = self.verifyOnBoard(location: stone.location)
            assert(isOnBoard, message: "Stone location".concat(stone.location.description()).concat(" is invalid."))

            // check location not yet taken.
            assert(self.locationStoneMap[stone.key()] == nil, message: "This place had been taken.")

            if roundSteps.length % 2 == 0 {
                // black stone move
                assert(stone.color == GomokuType.StoneColor.black, message: "It should be black side's turn.")
            } else {
                // white stone move
                assert(stone.color == GomokuType.StoneColor.white, message: "It should be white side's turn.")
            }

            let GomokuType.StoneColor = stone.color
            let stoneLocation = stone.location
            self.locationStoneMap[stone.key()] = GomokuType.StoneColor
            self.steps[self.currentRound].append(<- stone)
        }

        priv fun verifyOnBoard(location: StoneLocation): Bool {
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

        priv fun checkWinnerInAllDirection(targetColor: GomokuType.StoneColor, center: StoneLocation): Bool {
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
            center: StoneLocation,
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
                    let currentCheckedLocation = StoneLocation(x: center.x - shift, y: center.y)
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
                    let currentCheckedLocation = StoneLocation(x: center.x + shift, y: center.y)
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
                    let currentCheckedLocation = StoneLocation(x: center.x, y: center.y - shift)
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
                    let currentCheckedLocation = StoneLocation(x: center.x, y: center.y + shift)
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
                    let currentCheckedLocation = StoneLocation(x: center.x - shift, y: center.y - shift)
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
                    let currentCheckedLocation = StoneLocation(x: center.x + shift, y: center.y + shift)
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
                    let currentCheckedLocation = StoneLocation(x: center.x - shift, y: center.y + shift)
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
                    let currentCheckedLocation = StoneLocation(x: center.x + shift, y: center.y - shift)
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
    ): @CompositionCollection {

        let Composition <- create Composition(
            id: id,
            host: host,
            boardSize: boardSize,
            totalRound: totalRound
        )
        emit CompositionCreated(host: host)

        return <- Composition
    }

    pub resource CompositionCollection: GomokuCompositioning.CompositionCollecting {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        priv var ownedCompositionMap: @{UInt32: Composition}
        priv var destroyable: Bool

        init () {
            self.ownedCompositionMap <- {}
            self.destroyable = false
            self.StoragePath = /storage/gomokuCollection
            self.PublicPath = /public/gomokuCollection
        }

        access(account) fun withdraw(by id: UInt32): @Composition {
            let token <- self.ownedCompositionMap.remove(key: id) ?? panic("missing Composition")
            emit Withdraw(id: token.id, from: self.owner?.address)
            if self.ownedCompositionMap.keys.length == 0 {
                self.destroyable = true
            }
            return <- token
        }

        access(account) fun deposit(token: @Composition) {
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

        pub fun borrow(id: UInt32): &Composition? {
            return &self.ownedCompositionMap[id] as &Composition?
        }

        destroy() {
            destroy self.ownedCompositionMap
            if self.destroyable == false {
                panic("Ha Ha! Got you! You can't destory this collection if there are Gomoku Composition!")
            }
        }
    }

    access(account) fun createEmptyVault(): @CompositionCollection {
        emit CollectionCreated()
        return <- create CompositionCollection()
    }

    pub struct StoneLocation: GomokuType.StoneLocating {

        pub let x: Int8
        pub let y: Int8

        init(x: Int8, y: Int8) {
            self.x = x
            self.y = y
        }

        pub fun key(): String {
            return self.x.toString().concat(",").concat(self.y.toString())
        }

        pub fun description(): String {
            return "x: ".concat(self.x.toString()).concat(", y: ").concat(self.y.toString())
        }

    }

    pub struct StoneData: GomokuType.StoneDataing {
        pub let color: GomokuType.StoneColor
        pub let location: StoneLocation

        init(
            color: GomokuType.StoneColor,
            location: StoneLocation
        ) {
            self.color = color
            self.location = location
        }
    }

    pub resource Stone: GomokuType.Stoning {
        pub let color: GomokuType.StoneColor
        pub let location: StoneLocation

        init(
            color: GomokuType.StoneColor,
            location: StoneLocation
        ) {
            self.color = color
            self.location = location
        }

        pub fun key(): String {
            return self.location.key()
        }

        pub fun convertToData(): StoneData {
            return StoneData(
                color: self.color,
                location: self.location
            )
        }
    }

}