import Crypto
import MatchContract from "./MatchContract.cdc"
import FungibleToken from "./FungibleToken.cdc"
import BloctoToken from "./BloctoToken.cdc"
import FlowToken from 0x0ae53cb6e3f42a79
// import FlowToken from "./FlowToken.cdc"
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

    // 
    pub event BetType(
        type: Type,
        balance: UFix64)

    init() {
        self.CollectionStoragePath = /storage/gomokuCollection
        self.CollectionPublicPath = /public/gomokuCollection
        self.compositionMatcher = MatchContract.Matcher()

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
            contractAddress: self.account.address,
            boardSize: 15,
            openingBets: <- eachBets)

        let currency = composition.getBetCurrency()
        let totalBets = composition.getAllBets()

        // Create a new Gomoku and put it in storage
        host.save(<-composition, to: self.CollectionStoragePath)

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        host.link<&Gomoku.Composition{Gomoku.PublicCompositioning}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
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
    access(account) fun setActivateRegistration(_ active: Bool) {
        self.compositionMatcher.setActivateRegistration(active)
    }

    access(account) fun setActivateMatching(_ active: Bool) {
        self.compositionMatcher.setActivateMatching(active)
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

        pub fun switchRound()
    }

    pub resource Composition: PublicCompositioning {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: UInt8

        pub var openingBets: @[FungibleToken.Vault]

        priv var compositionContractAddress: Address
        priv var challenger: Address?
        priv var raisedBets: @[[FungibleToken.Vault]]
        priv var steps: @[[Stone]]
        priv var locationStoneMap: {String:StoneColor}

        // timeout of block height
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

        init(
            contractAddress: Address,
            boardSize: UInt8,
            openingBets: @[FungibleToken.Vault]
        ) {
            pre {
                openingBets.length == 2: "Total round should be 2 and take turns to make first move (black stone) for fairness."
            }

            self.StoragePath = /storage/gomokuCollection
            self.PublicPath = /public/gomokuCollection

            self.boardSize = boardSize
            self.compositionContractAddress = contractAddress
            self.challenger = nil
            self.totalRound = UInt8(openingBets.length)
            self.currentRound = 0
            self.openingBets <- openingBets
            self.raisedBets <- []
            self.steps <- []
            self.locationStoneMap = {}
            let firstOpeningBetType = self.openingBets[0].getType()

            var index: Int = 0
            while index < self.openingBets.length {
                let indexType = self.openingBets[index].getType()
                assert(
                    firstOpeningBetType == indexType,
                    message: "Every bets should be same token "
                        .concat(firstOpeningBetType.identifier)
                        .concat(" but found ")
                        .concat(indexType.identifier)
                        .concat(" at index ")
                        .concat(index.toString())
                        .concat(" instead."))
                self.raisedBets.append(<- [])
                self.steps.append(<- [])
                index = index + 1
            }

            self.latestBlockHeight = getCurrentBlock().height
            self.blockHeightTimeout = UInt64(60 * 60 * 24 * 7)

            let isValidVault = self.checkVaultValid(firstOpeningBetType)
            assert(isValidVault, message: "Only support Flow Token, Blocto Token, tUSDT right now.")
        }

        // Script
        pub fun getBets(round: UInt8): UFix64 {
            pre {
                round < self.totalRound - 1: "Input round (start from 0) should be less than or equal to total rounds."
            }
            var totalRaisedBets = UFix64(0)
            var index = 0
            while index < self.raisedBets[round].length {
                let raisedBet = &self.raisedBets[round][index] as &FungibleToken.Vault
                totalRaisedBets = totalRaisedBets + raisedBet.balance
                index = index + 1
            }
            return self.openingBets[round].balance + totalRaisedBets
        }

        pub fun getAllBets(): UFix64 {
            var sum = UFix64(0)
            var index = 0
            while index < self.openingBets.length {
                let openingBet = &self.openingBets[index] as &FungibleToken.Vault
                sum = sum + openingBet.balance
                index = index + 1
                var innerIndex = 0
                while innerIndex < self.raisedBets[index].length {
                    let raisedBet = &self.raisedBets[index][innerIndex] as &FungibleToken.Vault
                    sum = sum + raisedBet.balance
                    innerIndex = innerIndex + 1
                }
            }
            return sum
        }

        pub fun getBetCurrency(): String {
            pre {
                self.openingBets.length > 0: "Opening bet not found."
            }
            let openingBetType = self.openingBets[0].getType()
            if openingBetType == Type<@FlowToken.Vault>() {
                return "Flow Token"
            } else if openingBetType == Type<@BloctoToken.Vault>() {
                return "Blocto Token"
            } else if openingBetType == Type<@TeleportedTetherToken.Vault>() {
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
            // check raise bet type
            let openingBetType = self.openingBets[self.currentRound].getType()
            assert(raisedBet.getType() == openingBetType, message: "RaisedBets's type should be equal to opening bet's.")
            self.raisedBets[self.currentRound].append(<- raisedBet)

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
        }

        pub fun switchRound() {
            pre {
                self.totalRound > self.currentRound + 1: "Next round should not over totalRound."
            }
            self.currentRound = self.currentRound + 1
        }

        // Private Method
        priv fun checkVaultValid(_ type: Type): Bool {
            return [
                Type<@FlowToken.Vault>(),
                Type<@BloctoToken.Vault>(),
                Type<@TeleportedTetherToken.Vault>()
            ].contains(type)
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

        priv fun recycleBets() {
            var roundIndex = 0
            while roundIndex < self.openingBets.length {
                var index = 0
                let openingBetType = self.openingBets[roundIndex].getType()
                let compositionContractAccount = getAccount(self.compositionContractAddress)
                if openingBetType == Type<@FlowToken.Vault>() {
                    let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    let flowVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    flowVaultReference.deposit(from: <- self.openingBets.remove(at: roundIndex))
                    while index < self.raisedBets[roundIndex].length {
                        if self.raisedBets[roundIndex][index].getType() == openingBetType {
                            flowVaultReference.deposit(from: <- self.raisedBets[roundIndex].remove(at: index))
                        }
                        index = index + 1
                    }
                } else if openingBetType == Type<@BloctoToken.Vault>() {
                    let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(BloctoToken.TokenPublicReceiverPath)
                    let bltVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    bltVaultReference.deposit(from: <- self.openingBets.remove(at: roundIndex))
                    while index < self.raisedBets[roundIndex].length {
                        if self.raisedBets[roundIndex][index].getType() == openingBetType {
                            bltVaultReference.deposit(from: <- self.raisedBets[roundIndex].remove(at: index))
                        }
                        index = index + 1
                    }
                } else if openingBetType == Type<@TeleportedTetherToken.Vault>() {
                    let capability = compositionContractAccount.getCapability<&AnyResource{FungibleToken.Receiver}>(TeleportedTetherToken.TokenPublicReceiverPath)
                    let tUSDTVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    tUSDTVaultReference.deposit(from: <- self.openingBets.remove(at: roundIndex))
                    while index < self.raisedBets[roundIndex].length {
                        if self.raisedBets[roundIndex][index].getType() == openingBetType {
                            tUSDTVaultReference.deposit(from: <- self.raisedBets[roundIndex].remove(at: index))
                        }
                        index = index + 1
                    }
                }
                roundIndex = roundIndex + 1
            }
        }

        destroy() {
            self.recycleBets()
            destroy self.openingBets
            destroy self.raisedBets
            destroy self.steps
        }

    }

}