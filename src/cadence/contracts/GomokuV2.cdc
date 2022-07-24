import MatchContract from "./MatchContract.cdc"
import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import BloctoToken from "./BloctoToken.cdc"
import FlowToken from 0x0ae53cb6e3f42a79
// import FlowToken from "./FlowToken.cdc"
import TeleportedTetherToken from "./TeleportedTetherToken.cdc"

pub contract Gomoku: NonFungibleToken {

    // path
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub var totalSupply: UInt64

    pub var collection: @Collection

    pub event ContractInitialized()

    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event CompositionCreated(
        host: Address,
        currency: String,
        hostOpeningBet: UFix64)

    // Event that is emitted when the contract is created
    pub event CompositionMatched(
        host: Address,
        challenger: Address,
        currency: String,
        openingBet: UFix64)

    // 
    pub event BetType(
        type: Type,
        balance: UFix64)

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

    // Transaction
    pub fun createEmptyCollection(): @Collection {
        
    }

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

        let currency = composition.getBetCurrency()
        let openingBet = composition.getAllBets()

        emit CompositionCreated(
            host: host,
            currency: currency,
            hostOpeningBet: openingBet)

        return <- composition
    }

    pub fun matchOpponent(
        index: UInt32,
        challenger: Address,
        bet: @FungibleToken.Vault
    ): @IdentityToken? {
        if let matchedHost = MatchContract.match(index: index, challenger: challenger) {
            let publicCapability = getAccount(matchedHost).getCapability(self.CollectionPublicPath)
            if let collectionPublicRef = publicCapability.borrow<&Gomoku.Composition{Gomoku.PublicCompositioning}>() {
                let identityToken <- collectionPublicRef.match(
                    challenger: challenger,
                    bet: <- bet)

                emit CompositionMatched(
                    host: matchedHost,
                    challenger: challenger,
                    currency: collectionPublicRef.getBetCurrency(),
                    openingBet: collectionPublicRef.getAllBets())
                return <- identityToken
            }
        }
        panic("Match failed, please try again.")
        return nil
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

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver {

        access(account) var ownedCompositions: @{UInt32: Composition}

        pub fun getIds(): [UInt32] {
            return self.ownedNFTs.keys
        }

        pub fun withdraw(id: UInt32): @NFT {
            post {
                result.id == withdrawID: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }

        pub fun deposit(token: @NFT) {

        }
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
    }

    pub resource interface IdentitySwitching {
        access(account) fun switchIdentity()
    }

    pub resource IdentityToken: IdentitySwitching {
        pub let id: UInt32
        pub let address: Address
        pub var stoneColor: StoneColor

        access(account) init(
            id: UInt32,
            address: Address,
            stoneColor: StoneColor
        ) {
            self.id = id
            self.address = address
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
        pub fun getBetCurrency(): String
        pub fun getBetCurrencyType(): Type
        pub fun getOpeningBet(): UFix64
        pub fun getAllBets(): UFix64
        pub fun getTimeout(): UInt64

        // Transaction
        pub fun match(
            challenger: Address,
            bet: @FungibleToken.Vault
        ): IdentityToken

        pub fun makeMove(
            identityToken: @IdentityToken,
            stone: @Stone,
            raisedBet: @FungibleToken.Vault
        )
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

        priv var claimed: Bool

        access(self) let openingBet: @FungibleToken.Vault
        access(self) let hostRaisedBet: @FungibleToken.Vault
        access(self) let challengerRaisedBet: @FungibleToken.Vault

        priv var compositionContractAddress: Address
        priv var host: Address
        priv var challenger: Address?
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
            self.claimed = false
            self.openingBet <- hostOpeningBet
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
        pub fun getBetCurrency(): String {
            let openingBetType = self.openingBet.getType()
            if openingBetType == Type<@FlowToken.Vault>() {
                return "Flow Token"
            } else if openingBetType == Type<@BloctoToken.Vault>() {
                return "Blocto Token"
            } else if openingBetType == Type<@TeleportedTetherToken.Vault>() {
                return "tUSDT Token"
            }
            panic("Currency can't be identify.")
        }

        pub fun getBetCurrencyType(): Type {
            return self.openingBet.getType()
        }

        pub fun getOpeningBet(): UFix64 {
            let openingBetRef = &self.openingBet as? &FungibleToken.Vault
            return openingBetRef.balance
        }

        pub fun getAllBets(): UFix64 {
            let openingBetRef = &self.openingBet as? &FungibleToken.Vault
            let hostRaisedBetRef = &self.hostRaisedBet.balance as? &FungibleToken.Vault
            let challengerRaisedBetRef = &self.challengerRaisedBet.balance as? &FungibleToken.Vault
            return openingBetRefingBet.balance + hostRaisedBetRef.balance + challengerRaisedBetRef.balance
        }

        pub fun getTimeout(): UInt64 {
            return self.latestBlockHeight + self.blockHeightTimeout
        }

        // Transaction
        pub fun claim(host: Address): @IdentityToken {
            pre {
                self.claimed == false: "Already claimed."
            }
            post {
                self.claimed == true: "Not claim yet."
            }
            self.claimed = true
            // generate identity token to identify who take what stone in case someone takes other's move.
            let identity <- create IdentityToken(
                id: self.id,
                address: host,
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
                stoneColor: StoneColor.black
            )
            return <- identity
        }

        pub fun makeMove(
            identityToken: @IdentityToken,
            stone: @Stone,
            raisedBet: @FungibleToken.Vault
        ): @IdentityToken {
            // check identity
            pre {
                identityToken.stoneColor == stone.color: "You are not suppose to make this move."
            }

            // check raise bet type
            assert(
                raisedBet.getType() == self.openingBet.getType(),
                message: "RaisedBets's type should be equal to opening bet's.")

            if self.currentRound % 2 == 0 {
                // first move is challenger if index is even
                if self.steps.length % 2 == 0 {
                    // step for challenger
                    self.challengerRaisedBet.deposit(from: <- raisedBet)
                } else {
                    // step for host
                    self.hostRaisedBet.deposit(from: <- raisedBet)
                }
            } else {
                // first move is host if index is odd
                if self.steps.length % 2 == 0 {
                    // step for host
                    self.hostRaisedBet.deposit(from: <- raisedBet)
                } else {
                    // step for challenger
                    self.challengerRaisedBet.deposit(from: <- raisedBet)
                }
            }

            let stoneRef = &stone as &Stone

            // validate move
            self.verifyAndStoreStone(stone: <- stone)

            let hasWinner = self.checkWinnerInAllDirection(
                targetColor: stoneRef.color,
                center: stoneRef.location)
            if hasWinner {
                // event
                // end of current round
                if self.currentRound + UInt8(1) < self.totalRound {
                    self.switchRound()
                } else {
                    // end of game
                    // distribute reward
                }
            }

            // reset timeout
            self.latestBlockHeight = getCurrentBlock().height
            return <- identityToken
        }

        // Private Method
        priv fun switchRound() {
            pre {
                self.totalRound > self.currentRound + 1: "Next round should not over totalRound."
            }
            self.currentRound = self.currentRound + 1
            let hostCapability = self.host.getCapability<&Gomoku.IdentityToken{Gomoku.IdentitySwitching}>(self.IdentityPublicPath)
            hostCapability.switchIdentity()

            if let challengerCapability = self.challenger?.getCapability<&Gomoku.IdentityToken{Gomoku.IdentitySwitching}>(self.IdentityPublicPath) {
                challengerCapability.switchIdentity()
            } else {
                panic("challenger not found.")
            }
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

        priv fun recycleBets() {
            let openingBetType = self.openingBet.getType()
            let compositionContractAccount = getAccount(self.compositionContractAddress)
            if openingBetType == Type<@FlowToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                let flowVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                flowVaultReference.deposit(from: <- self.openingBet)
                if self.hostRaisedBet.getType() == openingBetType {
                    flowVaultReference.deposit(from: <- self.hostRaisedBet)
                }
                if self.challengerRaisedBet.getType() == openingBetType {
                    flowVaultReference.deposit(from: <- self.challengerRaisedBet)
                }
            } else if openingBetType == Type<@BloctoToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(BloctoToken.TokenPublicReceiverPath)
                let bltVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                bltVaultReference.deposit(from: <- self.openingBet)
                if self.hostRaisedBet.getType() == openingBetType {
                    bltVaultReference.deposit(from: <- self.hostRaisedBet)
                }
                if self.challengerRaisedBet.getType() == openingBetType {
                    bltVaultReference.deposit(from: <- self.challengerRaisedBet)
                }
            } else if openingBetType == Type<@TeleportedTetherToken.Vault>() {
                let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(TeleportedTetherToken.TokenPublicReceiverPath)
                let tUSDTVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                tUSDTVaultReference.deposit(from: <- self.openingBet)
                if self.hostRaisedBet.getType() == openingBetType {
                    tUSDTVaultReference.deposit(from: <- self.hostRaisedBet)
                }
                if self.challengerRaisedBet.getType() == openingBetType {
                    tUSDTVaultReference.deposit(from: <- self.challengerRaisedBet)
                }
            }
        }

        destroy() {
            self.recycleBets()
            destroy self.openingBet
            destroy self.raisedBets
            destroy self.steps
        }

    }

}