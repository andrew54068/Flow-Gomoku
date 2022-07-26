import MatchContract from "./MatchContract.cdc"
import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import BloctoToken from "./BloctoToken.cdc"
// import FlowToken from 0x0ae53cb6e3f42a79
import FlowToken from "./FlowToken.cdc"
import TeleportedTetherToken from "./TeleportedTetherToken.cdc"

pub contract Gomoku {

    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Events
    // Event be emitted when the composition is created
    pub event CompositionCreated(
        host: Address,
        currency: String,
        hostOpeningBet: UFix64)

    // Event be emitted when the contract is created
    pub event CompositionMatched(
        host: Address,
        challenger: Address,
        currency: String,
        openingBet: UFix64)

    init() {
        self.CollectionStoragePath = /storage/gomokuCollection
        self.CollectionPublicPath = /public/gomokuCollection

        if self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
            let flowVault <- FlowToken.createEmptyVault()
            self.account.save(<- flowVault, to: /storage/flowTokenVault)
        }

        if self.account.borrow<&BloctoToken.Vault>(from: BloctoToken.TokenStoragePath) == nil {
            let bltVault <- BloctoToken.createEmptyVault()
            self.account.save(<- bltVault, to: BloctoToken.TokenStoragePath)
        }

        if self.account.borrow<&TeleportedTetherToken.Vault>(from: TeleportedTetherToken.TokenStoragePath) == nil {
            let tUSDTVault <- TeleportedTetherToken.createEmptyVault()
            self.account.save(<- tUSDTVault, to: TeleportedTetherToken.TokenStoragePath)
        }
    }

    pub fun getCompositionRef(by index: UInt32): &AnyResource{Gomoku.PublicCompositioning}? {
        if let host = MatchContract.getHostAddress(by: index) {
            let publicCapability = getAccount(host).getCapability(self.CollectionPublicPath)
            return publicCapability.borrow<&Gomoku.Composition{Gomoku.PublicCompositioning}>()
        } else {
            return nil
        }
    }

    pub fun getParticipants(by index: UInt32): [Address] {
        if let host = MatchContract.getHostAddress(by: index) {
            let publicCapability = getAccount(host).getCapability(self.CollectionPublicPath)
            let conpisitionRef = publicCapability.borrow<&Gomoku.Composition{Gomoku.PublicCompositioning}>()
            return conpisitionRef?.getParticipants() ?? []
        } else {
            return []
        }
    }

    // Transaction
    pub fun register(
        host: Address,
        openingBet: @FungibleToken.Vault,
    ): @Composition {
        let index = MatchContract.register(host: host)

        let composition: @Composition <- create Composition(
            id: index,
            host: host,
            contractAddress: self.account.address,
            boardSize: 15,
            totalRound: 2,
            hostOpeningBet: <- openingBet)

        let currencyType = composition.getBetCurrencyType()
        let openingBet = composition.getAllBets()

        emit CompositionCreated(
            host: host,
            currency: currencyType.identifier,
            hostOpeningBet: openingBet)

        return <- composition
    }

    pub fun matchOpponent(
        index: UInt32,
        challenger: Address,
        bet: @FungibleToken.Vault,
        recycleBetVaultRef: &AnyResource{FungibleToken.Receiver}
    ): @IdentityToken? {
        if let matchedHost = MatchContract.match(index: index, challengerAddress: challenger) {
            let publicCapability = getAccount(matchedHost).getCapability(self.CollectionPublicPath)
            if let compositionRef = publicCapability.borrow<&Gomoku.Composition{Gomoku.PublicCompositioning}>() {
                let identityToken <- compositionRef.match(
                    challenger: challenger,
                    bet: <- bet)

                emit CompositionMatched(
                    host: matchedHost,
                    challenger: challenger,
                    currency: compositionRef.getBetCurrencyType().identifier,
                    openingBet: compositionRef.getAllBets())

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

    pub fun getOpeningBetType(by index: UInt32): Type? {
        if let host = MatchContract.getHostAddress(by: index) {
            let publicCapability = getAccount(host).getCapability(self.CollectionPublicPath)
            if let collectionPublicRef = publicCapability.borrow<&Gomoku.Composition{Gomoku.PublicCompositioning}>() {
                return collectionPublicRef.getBetCurrencyType()
            }
        }
        return nil
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

    pub resource interface IdentitySwitching {
        access(account) fun switchIdentity()
    }

    pub resource IdentityToken: IdentitySwitching {
        pub let id: UInt32
        pub let address: Address
        pub let role: Role
        pub var stoneColor: StoneColor

        access(account) init(
            id: UInt32,
            address: Address,
            role: Role,
            stoneColor: StoneColor
        ) {
            self.id = id
            self.address = address
            self.role = role
            self.stoneColor = stoneColor
        }

        access(account) fun switchIdentity() {
            switch self.stoneColor {
            case StoneColor.black:
                self.stoneColor = StoneColor.white
            case StoneColor.white:
                self.stoneColor = StoneColor.black
            }
        }
    }

    pub enum VerifyDirection: UInt8 {
        pub case vertical
        pub case horizontal
        pub case diagonal // "/"
        pub case reversedDiagonal // "\"
    }

    pub resource interface PublicCompositioning {
        // Script
        pub fun getBetCurrencyType(): Type
        pub fun getOpeningBet(): UFix64
        pub fun getAllBets(): UFix64
        pub fun getTimeout(): UInt64
        pub fun getStoneData(for: UInt8): [[UInt8]]
        pub fun getParticipants(): [Address]

        // Transaction
        pub fun match(
            challenger: Address,
            bet: @FungibleToken.Vault
        ): @IdentityToken

        pub fun makeMove(
            identityToken: @IdentityToken,
            stone: @Stone,
            raisedBet: @FungibleToken.Vault,
            hasRoundWinnerCallback: ((Bool): Void)
        ): @IdentityToken
    }

    pub enum Role: UInt8 {
        pub case host
        pub case challenger
    }

    pub resource Composition: PublicCompositioning {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        pub let IdentityStoragePath: StoragePath
        pub let IdentityPublicPath: PublicPath

        pub let id: UInt32

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: UInt8

        priv var claimedHost: Bool
        priv var winner: Role?

        access(self) let openingBet: @FungibleToken.Vault
        access(self) let hostRaisedBet: @FungibleToken.Vault
        access(self) let challengerRaisedBet: @FungibleToken.Vault

        priv var compositionContractAddress: Address
        priv var host: Address
        priv var challenger: Address?
        priv var roundWiners: [Role]
        priv var steps: @[[Stone]]
        priv var locationStoneMap: {String:StoneColor}

        // timeout of block height
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

        init(
            id: UInt32,
            host: Address,
            contractAddress: Address,
            boardSize: UInt8,
            totalRound: UInt8,
            hostOpeningBet: @FungibleToken.Vault
        ) {
            pre {
                totalRound >= 2: "Total round should be 2 to take turns to make first move (black stone) for fairness."
                totalRound % 2 == 0: "Total round should be event number to take turns to make first move (black stone) for fairness."
            }

            self.StoragePath = /storage/gomokuCollection
            self.PublicPath = /public/gomokuCollection

            self.IdentityStoragePath = /storage/compositionIdentity
            self.IdentityPublicPath = /public/compositionIdentity

            self.id = id
            self.host = host
            self.boardSize = boardSize
            self.compositionContractAddress = contractAddress
            self.challenger = nil
            self.totalRound = totalRound
            self.currentRound = 0
            self.claimedHost = false
            self.winner = nil
            self.openingBet <- hostOpeningBet
            self.roundWiners = []
            self.steps <- []
            self.locationStoneMap = {}

            let openingBetType = self.openingBet.getType()
            if openingBetType == Type<@FlowToken.Vault>() {
                // flow token
                self.hostRaisedBet <- FlowToken.createEmptyVault()
                self.challengerRaisedBet <- FlowToken.createEmptyVault()
            } else if openingBetType == Type<@BloctoToken.Vault>() {
                // blocto token
                self.hostRaisedBet <- BloctoToken.createEmptyVault()
                self.challengerRaisedBet <- BloctoToken.createEmptyVault()
            } else if openingBetType == Type<@TeleportedTetherToken.Vault>() {
                // TeleportedTetherToken token
                self.hostRaisedBet <- TeleportedTetherToken.createEmptyVault()
                self.challengerRaisedBet <- TeleportedTetherToken.createEmptyVault()
            } else {
                self.hostRaisedBet <- FlowToken.createEmptyVault()
                self.challengerRaisedBet <- FlowToken.createEmptyVault()
                panic("Only support Flow Token, Blocto Token, tUSDT right now.")
            }

            self.latestBlockHeight = getCurrentBlock().height
            self.blockHeightTimeout = UInt64(60 * 60 * 24 * 7)
        }

        // Script
        pub fun getBetCurrencyType(): Type {
            return self.openingBet.getType()
        }

        pub fun getOpeningBet(): UFix64 {
            let openingBetRef = &self.openingBet as? &FungibleToken.Vault
            return openingBetRef.balance
        }

        pub fun getAllBets(): UFix64 {
            let openingBetRef = &self.openingBet as? &FungibleToken.Vault
            let hostRaisedBetRef = &self.hostRaisedBet as? &FungibleToken.Vault
            let challengerRaisedBetRef = &self.challengerRaisedBet as? &FungibleToken.Vault
            return openingBetRef.balance + hostRaisedBetRef.balance + challengerRaisedBetRef.balance
        }

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
        pub fun claim(host: Address): @IdentityToken {
            pre {
                self.claimedHost == false: "Already claimed."
            }
            post {
                self.claimedHost == true: "Not claim yet."
            }
            self.claimedHost = true
            // generate identity token to identify who take what stone in case someone takes other's move.
            let identity <- create IdentityToken(
                id: self.id,
                address: host,
                role: Role.host,
                stoneColor: StoneColor.white
            )
            return <- identity
        }

        pub fun match(
            challenger: Address,
            bet: @FungibleToken.Vault
        ): @IdentityToken {
            pre {
                self.challenger == nil: "Already matched."
            }
            self.challenger = challenger
            self.openingBet.deposit(from: <- bet)

            // generate identity token to identify who take what stone in case someone takes other's move.
            let identity <- create IdentityToken(
                id: self.id,
                address: challenger,
                role: Role.challenger,
                stoneColor: StoneColor.black
            )
            return <- identity
        }

        pub fun makeMove(
            identityToken: @IdentityToken,
            stone: @Stone,
            raisedBet: @FungibleToken.Vault,
            hasRoundWinnerCallback: ((Bool): Void)
        ): @IdentityToken {
            // check identity
            pre {
                identityToken.stoneColor == stone.color: "You are not suppose to make this move."
                identityToken.id == self.id: "You are not authorized to make this move."
                identityToken.owner?.address == identityToken.address: "Identity token should not be transfer to other."
                Int(self.currentRound) + 1 > self.roundWiners.length: "Game Over."
            }

            // check raise bet type
            assert(
                raisedBet.getType() == self.openingBet.getType(),
                message: "You can onlty raise bet with the same token of opening bet: "
                    .concat(raisedBet.getType().identifier)
            )

            let lastRole = self.getRole()
            var currentRole = Role.host
            switch lastRole {
            case Role.host:
                currentRole = Role.challenger
                assert(self.challenger != nil, message: "Challenger not found.")
                assert(identityToken.address == self.challenger!, message: "It's not you turn yet!")
            case Role.challenger:
                currentRole = Role.host
                assert(identityToken.address == self.host, message: "It's not you turn yet!")
            }

            switch currentRole {
            case Role.host:
                self.hostRaisedBet.deposit(from: <- raisedBet)
            case Role.challenger:
                self.challengerRaisedBet.deposit(from: <- raisedBet)
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

        pub fun surrender(identityToken: @IdentityToken) {
            pre {
                identityToken.id == self.id: "You are not authorized to make this move."
            }

            destroy identityToken
        }

        pub fun finalize() {
            // distribute reward

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

        // Private Method
        // Challenger go first in first round
        priv fun getRole(): Role {
            if self.currentRound % 2 == 0 {
                // first move is challenger if index is even
                if self.steps.length % 2 == 0 {
                    // step for challenger
                    return Role.challenger
                } else {
                    // step for host
                    return Role.host
                }
            } else {
                // first move is host if index is odd
                if self.steps.length % 2 == 0 {
                    // step for host
                    return Role.host
                } else {
                    // step for challenger
                    return Role.challenger
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
            let hostCapability = getAccount(self.host).getCapability<&Gomoku.IdentityToken{Gomoku.IdentitySwitching}>(self.IdentityPublicPath)
            let hostIdentitySwitchingRef = hostCapability.borrow() ?? panic("Could not borrow a reference to the host capability.")
            hostIdentitySwitchingRef.switchIdentity()

            assert(self.challenger != nil, message: "Challenger not found.")

            let challengerCapability = getAccount(self.challenger!).getCapability<&Gomoku.IdentityToken{Gomoku.IdentitySwitching}>(self.IdentityPublicPath)
            let challengerIdentitySwitchingRef = challengerCapability.borrow() ?? panic("Could not borrow a reference to the challenger capability.")
            challengerIdentitySwitchingRef.switchIdentity()
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
                case Role.host:
                    // developer get 5% for developing this game
                    // winner get 95%

                case Role.challenger:
                    // developer get 5% for developing this game
                    // host get extra 2% for being host.
                    // winner get 93%.

                default:
                    panic("Should not be the case.")
                }
            } else {
                // draw
                // developer get 2% for developing this game
                // each player get 49%.
            }


            let roundSteps = &self.steps[self.currentRound] as &[Stone]
            
            let lastStep = &roundSteps[roundSteps.length - 1] as &Stone
            let lastRole = self.getRole()
            switch lastRole {
            case Role.host:
                // host wins
                
            case Role.challenger:
                // challenger wins
                if let challenger = self.challenger {

                } else {
                    panic("Challenger not found.")
                }
            }
        }

        priv fun withdrawBet(
            to: Address,
            vault: @FungibleToken.Vault
        ) {
            let betType = vault.getType()
            let compositionContractAccount = getAccount(self.compositionContractAddress)
            if betType == Type<@FlowToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                let flowReceiverReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                flowReceiverReference.deposit(from: <- vault)
            } else if betType == Type<@BloctoToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(BloctoToken.TokenPublicReceiverPath)
                let bltReceiverReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                bltReceiverReference.deposit(from: <- vault)
            } else if betType == Type<@TeleportedTetherToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(TeleportedTetherToken.TokenPublicReceiverPath)
                let tUSDTReceiverReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                tUSDTReceiverReference.deposit(from: <- vault)
            } else {
                panic("")
            }
        }

        priv fun recycleBets() {
            let openingBetType = self.openingBet.getType()
            let compositionContractAccount = getAccount(self.compositionContractAddress)
            if openingBetType == Type<@FlowToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                let flowReceiverReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                let withdrawBet <- self.openingBet.withdraw(amount: self.openingBet.balance)
                flowReceiverReference.deposit(from: <- withdrawBet)
                if self.hostRaisedBet.getType() == openingBetType {
                    let withdrawHostRaisedBet <- self.hostRaisedBet.withdraw(amount: self.hostRaisedBet.balance)
                    flowReceiverReference.deposit(from: <- withdrawHostRaisedBet)
                }
                if self.challengerRaisedBet.getType() == openingBetType {
                    let withdrawChallengerRaisedBet <- self.challengerRaisedBet.withdraw(amount: self.challengerRaisedBet.balance)
                    flowReceiverReference.deposit(from: <- withdrawChallengerRaisedBet)
                }
            } else if openingBetType == Type<@BloctoToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(BloctoToken.TokenPublicReceiverPath)
                let bltReceiverReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                let withdrawBet <- self.openingBet.withdraw(amount: self.openingBet.balance)
                bltReceiverReference.deposit(from: <- withdrawBet)
                if self.hostRaisedBet.getType() == openingBetType {
                    let withdrawHostRaisedBet <- self.hostRaisedBet.withdraw(amount: self.hostRaisedBet.balance)
                    bltReceiverReference.deposit(from: <- withdrawHostRaisedBet)
                }
                if self.challengerRaisedBet.getType() == openingBetType {
                    let withdrawChallengerRaisedBet <- self.challengerRaisedBet.withdraw(amount: self.challengerRaisedBet.balance)
                    bltReceiverReference.deposit(from: <- withdrawChallengerRaisedBet)
                }
            } else if openingBetType == Type<@TeleportedTetherToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(TeleportedTetherToken.TokenPublicReceiverPath)
                let tUSDTReceiverReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                let withdrawBet <- self.openingBet.withdraw(amount: self.openingBet.balance)
                tUSDTReceiverReference.deposit(from: <- withdrawBet)
                if self.hostRaisedBet.getType() == openingBetType {
                    let withdrawHostRaisedBet <- self.hostRaisedBet.withdraw(amount: self.hostRaisedBet.balance)
                    tUSDTReceiverReference.deposit(from: <- withdrawHostRaisedBet)
                }
                if self.challengerRaisedBet.getType() == openingBetType {
                    let withdrawChallengerRaisedBet <- self.challengerRaisedBet.withdraw(amount: self.challengerRaisedBet.balance)
                    tUSDTReceiverReference.deposit(from: <- withdrawChallengerRaisedBet)
                }
            }
        }

        destroy() {
            self.recycleBets()
            destroy self.openingBet
            destroy self.hostRaisedBet
            destroy self.challengerRaisedBet
            destroy self.steps
        }

    }

}