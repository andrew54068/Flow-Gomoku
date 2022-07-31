import Gomoku from "./Gomoku.cdc"
import GomokuIdentity from "./GomokuIdentity.cdc"

pub contract GomokuComposition {

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

    init() {
        self.CollectionStoragePath = /storage/gomokuCompositionCollection
        self.CollectionPublicPath = /public/gomokuCompositionCollection
    }

    pub resource interface PublicCompositioning {
        // Script
        pub fun getTimeout(): UInt64
        pub fun getStoneData(for: UInt8): [StoneData]
        pub fun getParticipants(): [Address]

        // Transaction
        access(account) fun match(
            challenger: Address
        ): @IdentityToken

        pub fun makeMove(
            identityToken: @GomokuIdentity.IdentityToken,
            stone: @Stone,
            raisedBet: @FlowToken.Vault,
            hasRoundWinnerCallback: ((Bool): Void)
        ): @IdentityToken
    }

    pub resource Composition: PublicCompositioning {

        pub let id: UInt32

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: UInt8

        priv var winner: Gomoku.Role?

        priv var host: Address
        priv var challenger: Address?
        priv var roundWiners: [Gomoku.Role]
        priv var steps: @[[Stone]]
        priv var locationStoneMap: {String:StoneColor}

        // timeout of block height
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

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
                color: StoneColor.black,
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
        access(account) fun match(challenger: Address): @GomokuIdentity.IdentityToken {
            pre {
                self.challenger == nil: "Already matched."
            }
            self.challenger = challenger

            // generate identity token to identify who take what stone in case someone takes other's move.
            let identity <- create IdentityToken(
                id: self.id,
                address: challenger,
                role: Gomoku.Role.challenger,
                stoneColor: StoneColor.black
            )
            return <- identity
        }

        pub fun makeMove(
            identityToken: @GomokuIdentity.IdentityToken,
            stone: @Stone,
            raisedBet: @FlowToken.Vault,
            hasRoundWinnerCallback: ((Bool): Void)
        ): @GomokuIdentity.IdentityToken {
            // check identity
            pre {
                identityToken.stoneColor == stone.color: "You are not suppose to make this move."
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
            var currentRole = Gomoku.Role.host
            switch lastRole {
            case Gomoku.Role.host:
                currentRole = Gomoku.Role.challenger
                assert(self.challenger != nil, message: "Challenger not found.")
                assert(identityToken.address == self.challenger!, message: "It's not you turn yet!")
            case Gomoku.Role.challenger:
                currentRole = Gomoku.Role.host
                assert(identityToken.address == self.host, message: "It's not you turn yet!")
            }

            switch currentRole {
            case Gomoku.Role.host:
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
            case Gomoku.Role.challenger:
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

            let hasRoundWinner = self.checkWinnerInAllDirection(
                targetColor: stoneRef.color,
                center: stoneRef.location)
            if hasRoundWinner {
                self.roundWiners.append(identityToken.role)
                // event
                // end of current round
                hasRoundWinnerCallback(hasRoundWinner)
                // if self.currentRound + UInt8(1) < self.totalRound {
                //     self.switchRound()
                // } else {
                //     // end of game
                //     // distribute reward
                //     self.distributeReward(abort: false)
                // }
            }

            // reset timeout
            self.latestBlockHeight = getCurrentBlock().height
            return <- identityToken
        }

        pub fun surrender(identityToken: @GomokuIdentity.IdentityToken): @GomokuIdentity.IdentityToken? {
            pre {
                identityToken.id == self.id: "You are not authorized to make this move."
            }
            switch identityToken.role {
            case Gomoku.Role.host:
                self.roundWiners[self.currentRound] = Gomoku.Role.challenger
            case Gomoku.Role.challenger:
                self.roundWiners[self.currentRound] = Gomoku.Role.host
            }
            if self.currentRound + 1 < self.totalRound {
                // switch to next round
                self.switchRound()
                return <- identityToken
            } else {
                // final round
                self.finalize()
                destroy identityToken
                return nil
            }
        }

        pub fun finalize() {
            // distribute reward
            self.distributeReward()
        }

        // Restricted to prevent from potential attack.
        access(account) fun finalizeByTimeout() {
            pre {
                getCurrentBlock().height > self.getTimeout(): "Let's give opponent more time to think......"
            }

            let lastRole = self.getRole()
            self.roundWiners.append(lastRole)
            if self.currentRound + UInt8(1) < self.totalRound {
                self.switchRound()
            } else {
                // end of game
                // distribute reward
                self.finalize()
            }
        }

        priv fun mintCompositionResult(identityToken: @GomokuIdentity.IdentityToken) {
            let resultCapability = getAccount(identityToken.address).getCapability<&Gomoku.ResultCollection>(Gomoku.ResultCollectionPublicPath)
            let resultCollectionRef = resultCapability.borrow() ?? panic("Could not borrow a reference to the host capability.")
            var steps: [[StoneData]] = []
            var index: UInt8 = 0
            while index < self.totalRound {
                steps.append(self.getStoneData(for: index))
                index = index + UInt8(1)
            }
            let resultToken <- create ResultToken(
                id: identityToken.id,
                steps: steps,
                winner: Address,
                losser: Address,
                gain: Fix64(0)
            )
            resultCollectionRef.deposit(token: <- resultToken)
            identityToken.setDestroyable(true)
            destroy identityToken
        }

        // Private Method
        // Challenger go first in first round
        priv fun getRole(): Gomoku.Role {
            if self.currentRound % 2 == 0 {
                // first move is challenger if index is even
                if self.steps.length % 2 == 0 {
                    // step for challenger
                    return Gomoku.Role.challenger
                } else {
                    // step for host
                    return Gomoku.Role.host
                }
            } else {
                // first move is host if index is odd
                if self.steps.length % 2 == 0 {
                    // step for host
                    return Gomoku.Role.host
                } else {
                    // step for challenger
                    return Gomoku.Role.challenger
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
            hostIdentityCollectionCapability.borrow(id: self.id).switchIdentity()

            assert(self.challenger != nil, message: "Challenger not found.")

            let challengerIdentityCollectionCapability = getAccount(self.challenger!)
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
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
                assert(stone.color == StoneColor.black, message: "It should be black side's turn.")
            } else {
                // white stone move
                assert(stone.color == StoneColor.white, message: "It should be white side's turn.")
            }

            let stoneColor = stone.color
            let stoneLocation = stone.location
            self.locationStoneMap[stone.key()] = stoneColor
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

        priv fun checkWinnerInAllDirection(targetColor: StoneColor, center: StoneLocation): Bool {
            return self.checkWinner(
                    targetColor: targetColor,
                    center: center,
                    direction: VerifyDirection.vertical)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: VerifyDirection.horizontal)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: VerifyDirection.diagonal)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: VerifyDirection.reversedDiagonal)
        }

        priv fun checkWinner(
            targetColor: StoneColor,
            center: StoneLocation,
            direction: VerifyDirection
        ): Bool {
            var countInRow: UInt8 = 1
            var shift: Int8 = 1
            var isFinished: Bool = false
            switch direction {
            case VerifyDirection.vertical:
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
            case VerifyDirection.horizontal:
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
            case VerifyDirection.diagonal:
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
            case VerifyDirection.reversedDiagonal:
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

        priv fun distributeReward() {
            pre {
                self.roundWiners.length == Int(self.totalRound): "Game not over yet!"
            }

            let firstRoundWinner = self.roundWiners[0]
            let secondRoundWinner = self.roundWiners[1]
            if firstRoundWinner == secondRoundWinner {
                let winner = firstRoundWinner
                // has winner
                switch winner {
                case Gomoku.Role.host:
                    // developer get 5% for developing this game
                    // host get extra 1% for being host.
                    // winner get 94%

                case Gomoku.Role.challenger:
                    // developer get 5% for developing this game
                    // host get extra 1% for being host.
                    // winner get 94%.

                // default:
                //     panic("Should not be the case.")
                }
            } else {
                // draw
                // developer get 2% for developing this game
                // each player get 49%.
            }
        }

        destroy() {
            destroy self.steps
        }

    }

    access(self) fun createComposition(
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

    pub resource CompositionCollection {

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

        access(account) pub fun deposit(token: @Composition) {
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
            return ownedCompositionMap.keys.length
        }

        pub fun borrow(id: UInt32): &Composition {
            return (&self.ownedCompositionMap[id] as &Composition?)!
        }

        destroy() {
            destroy self.ownedCompositionMap
            if self.destroyable == false {
                panic("Ha Ha! Got you! You can't destory this collection if there are Gomoku Composition!")
            }
        }
    }

    access(self) fun createEmptyVault(): @CompositionCollection {
        emit CollectionCreated()
        return <- create CompositionCollection()
    }

    pub enum StoneColor: UInt8 {
        // block stone go first
        pub case black
        pub case white
    }

    pub struct StoneLocation {

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

    pub struct StoneData {
        pub let color: StoneColor
        pub let location: StoneLocation

        init(
            color: StoneColor,
            location: StoneLocation
        ) {
            self.color = color
            self.location = location
        }
    }

    pub resource Stone {
        pub let color: StoneColor
        pub let location: StoneLocation

        init(
            color: StoneColor,
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

    pub enum VerifyDirection: UInt8 {
        pub case vertical
        pub case horizontal
        pub case diagonal // "/"
        pub case reversedDiagonal // "\"
    }

}