import Crypto
import MatchContract from "./MatchContract.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import FungibleToken from "./FungibleToken.cdc"
import BloctoToken from "./BloctoToken.cdc"
import FlowToken from "./FlowToken.cdc"
import TeleportedTetherToken from "./TeleportedTetherToken.cdc"

pub contract Gomoku {

    // path
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    access(account) let compositionMatcher: AnyStruct{MatchContract.Matching}

    pub event CompositionCreated(
        host: Address,
        currency: String,
        totalBets: UFix64)

    // Event that is emitted when the contract is created
    pub event CompositionMatched(
        host: Address,
        challenger: Address,
        currency: String,
        totalOpeningBets: UFix64)

    init() {
        self.CollectionStoragePath = /storage/gomokuCollection
        self.CollectionPublicPath = /public/gomokuCollection
        self.compositionMatcher = MatchContract.Matcher()

        if self.account.borrow<&FlowToken.Vault{FungibleToken.Receiver}>(from: /storage/flowTokenVault) == nil {
            let flowVault <- FlowToken.createEmptyVault()
            self.account.save(<- flowVault, to: /storage/flowTokenVault)
        }

        if self.account.borrow<&BloctoToken.Vault{FungibleToken.Receiver}>(from: BloctoToken.TokenStoragePath) == nil {
            let bltVault <- BloctoToken.createEmptyVault()
            self.account.save(<- bltVault, to: BloctoToken.TokenStoragePath)
        }

        if self.account.borrow<&TeleportedTetherToken.Vault{FungibleToken.Receiver}>(from: TeleportedTetherToken.TokenStoragePath) == nil {
            let tUSDTVault <- TeleportedTetherToken.createEmptyVault()
            self.account.save(<- tUSDTVault, to: TeleportedTetherToken.TokenStoragePath)
        }
    }

    // Script
    pub fun getWaitingIndex(hostAddress: Address): UInt32? {
        return self.compositionMatcher.getWaitingIndex(hostAddress: hostAddress)
    }
    pub fun getRandomWaitingIndex(): UInt32? {
        return self.compositionMatcher.getRandomWaitingIndex()
    }

    // Transaction
    pub fun register(
        host: AuthAccount,
        eachBets: @[FungibleToken.Vault],
    ) {
        self.compositionMatcher.register(host: host)

        let composition: @Composition <- create Composition(
            contractAccount: getAccount(self.account.address),
            boardSize: 15,
            totalRound: 2,
            openingBets: <- eachBets)

        let currency = composition.getBetCurrency()
        let totalBets = composition.getAllBets()

        // Create a new Gomoku and put it in storage
        host.save(<- composition, to: self.CollectionStoragePath)

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        host.link<&Gomoku.Composition{Gomoku.PublicCompositioning}>(
            self.CollectionStoragePath,
            target: self.CollectionPublicPath
        )

        emit CompositionCreated(
            host: host.address,
            currency: currency,
            totalBets: totalBets)
    }

    pub fun matchOpponent(
        index: UInt32, 
        challenger: AuthAccount
    ): Bool {
        if let matchedHost = self.compositionMatcher.match(index: index, challenger: challenger) {

            let capability = getAccount(matchedHost).getCapability(self.CollectionPublicPath)
            if let collectionRef = capability.borrow<&Composition>() {
                collectionRef.match(challenger: challenger)
                collectionRef.getAllBets()

                emit CompositionMatched(
                    host: matchedHost,
                    challenger: challenger.address,
                    currency: collectionRef.getBetCurrency(),
                    totalOpeningBets: collectionRef.getAllBets())
                return true
            }
        }
        panic("Match failed, please try again.")
    }

    // Matching flags
    access(account) fun activateRegistration() {
        self.compositionMatcher.registerActive = true
    }

    access(account) fun inactivateRegistration() {
        self.compositionMatcher.registerActive = false
    }

    access(account) fun activateMatching() {
        self.compositionMatcher.matchActive = true
    }

    access(account) fun inactivateMatching() {
        self.compositionMatcher.matchActive = false
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

    pub enum VerifyDirection: UInt8 {
        pub case vertical
        pub case horizontal
        pub case diagonal // "/"
        pub case reversedDiagonal // "\"
    }

    pub resource interface PublicCompositioning {
        // Script
        pub fun getBets(round: UInt8): UFix64
        pub fun getAllBets(): UFix64
        pub fun getBetCurrency(): String

        // Transaction
        pub fun match(challenger: AuthAccount)

        pub fun switchRound(nextRoundBet: UFix64)
    }

    pub resource Composition: PublicCompositioning {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: UInt8

        pub var openingBets: @[FungibleToken.Vault]

        priv var compositionContractAccount: PublicAccount
        priv var challenger: Address?
        priv var raisedBets: @[[FungibleToken.Vault]]
        priv var steps: @[[Stone]]
        priv var locationStoneMap: {String:StoneColor}

        // timeout of block height
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

        init(
            contractAccount: PublicAccount,
            boardSize: UInt8,
            totalRound: UInt8,
            openingBets: @[FungibleToken.Vault]
        ) {
            pre {
                totalRound == 2: "Total round should be 2 and take turns to make first move (black stone) for fairness."
                Int(totalRound) == openingBets.length: "Total round should be equal to openingBets length."
            }

            self.StoragePath = /storage/gomokuCollection
            self.PublicPath = /public/gomokuCollection

            self.boardSize = boardSize
            self.compositionContractAccount = contractAccount
            self.challenger = nil
            self.totalRound = totalRound
            self.currentRound = 0
            self.openingBets <- openingBets
            self.raisedBets <- []
            self.steps <- []
            self.locationStoneMap = {}
            let firstOpeningBet = openingBets[0]
            for index, bet in openingBets {
                if let flowVault = firstOpeningBet as? @FlowToken.Vault {
                    let vault = bet as? @FlowToken.Vault
                    assert(vault != nil, message: "Every bets should be FlowToken.")
                } else if let bltVault = firstOpeningBet as? @BloctoToken.Vault {
                    let vault = bet as? @BloctoToken.Vault
                    assert(vault != nil, message: "Every bets should be BloctoToken.")
                } else if let tUSDTVault = firstOpeningBet as? @TeleportedTetherToken.Vault {
                    let vault = bet as? @TeleportedTetherToken.Vault
                    assert(vault != nil, message: "Every bets should be TeleportedTetherToken.")
                } else {
                    panic("Only support Flow Token, Blocto Token right now.")
                }
                self.raisedBets.append(<- [])
                self.steps.append(<- [])
            }
            self.latestBlockHeight = getCurrentBlock().height
            self.blockHeightTimeout = UInt64(60 * 60 * 24 * 7)
        }

        // Script
        pub fun getBets(round: UInt8): UFix64 {
            pre {
                round < self.totalRound - 1: "Input round (start from 0) should be less than or equal to total rounds."
            }
            return self.openingBets[round].balance + self.raisedBets[round].balance
        }

        pub fun getAllBets(): UFix64 {
            var sum: UFix64 = UFix64(0)
            for index, openingBet in self.openingBets {
                sum = sum + openingBet.balance
                for raisedBet in self.raisedBets[index] {
                    sum = sum + raisedBet.balance
                }
            }
            return sum
        }

        pub fun getBetCurrency(): String {
            pre {
                self.openingBets.length > 0: "Opening bet not found."
            }
            let firstOpeningBet = self.openingBets[0]
            if let flowVault = firstOpeningBet as? @FlowToken.Vault {
                return "Flow Token"
            } else if let bltVault = firstOpeningBet as? @BloctoToken.Vault {
                return "Blocto Token"
            } else if let tUSDTVault = firstOpeningBet as? @TeleportedTetherToken.Vault {
                return "tUSDT Token"
            }
            panic("Currency can't be identify.")
        }

        pub fun getTimeout(): UInt64 {
            return self.latestBlockHeight + self.blockHeightTimeout
        }

        // Transaction
        pub fun match(challenger: AuthAccount) {
            self.challenger = challenger.address
        }

        pub fun makeMove(
            stone: @Stone,
            raisedBet: @FungibleToken.Vault
        ) {
            self.verifyAndStoreStone(stone: <- stone)
            assert(
                self.raisedBets.length == Int(self.totalRound),
                message: "RaisedBets's length should equal to totalRound's length")
            self.raisedBets[self.currentRound].append(<- raisedBet)
        }

        pub fun switchRound(nextRoundBet: UFix64) {
            pre {
                self.totalRound - 1 > self.currentRound: "This is already the final round."
                self.totalRound - 1 >= self.currentRound + 1: "Next round should not over totalRound."
            }
            post {
                self.openingBets.length == Int(self.currentRound) + 1: "Count of opening bet should equal to round current round."
            }
            self.currentRound = self.currentRound + 1
            self.openingBets.append(nextRoundBet)
        }

        // Private Method
        priv fun verifyAndStoreStone(stone: @Stone) {
            pre {
                self.steps.length == 2: "Steps length should be 2."
                self.currentRound <= 1: "Composition only has 2 round each."
            }
            let roundSteps <- self.steps[self.currentRound]

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
            roundSteps.append(<- stone)
            self.steps[self.currentRound] <-> roundSteps

            let hasWinner = self.checkWinnerInAllDirection(targetColor: stoneColor, center: stoneLocation)
            if hasWinner {
                // event
                // distribute reward
            }
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
            // let checkLocations: [StoneLocation] = []
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

        priv fun recycleBets(_ vaults: @[FungibleToken.Vault]) {
            let firstOpeningBet = self.openingBets[0]
            for openingBet in self.openingBets {
                if let flowVault = firstOpeningBet as? @FlowToken.Vault {
                    let capability = self.compositionContractAccount.getCapability(/public/flowTokenReceiver)
                    let flowVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    flowVaultReference.deposit(<- flowVault)
                } else if let bltVault = firstOpeningBet as? @BloctoToken.Vault {
                    let capability = self.compositionContractAccount.getCapability(BloctoToken.TokenPublicReceiverPath)
                    let bltVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    bltVaultReference.deposit(<- bltVault)
                } else if let tUSDTVault = firstOpeningBet as? @TeleportedTetherToken.Vault {
                    let capability = self.compositionContractAccount.getCapability(TeleportedTetherToken.TokenPublicReceiverPath)
                    let tUSDTVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    tUSDTVaultReference.deposit(<- tUSDTVault)
                } else {
                    break
                }
            }
        }

        destroy() {
            self.recycleBets(self.openingBets)
            self.recycleBets(self.raisedBets)
            destroy self.openingBets
            destroy self.raisedBets
            destroy self.steps
        }

    }

}