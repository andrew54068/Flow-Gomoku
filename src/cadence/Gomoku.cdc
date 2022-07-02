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

        if self.account.borrow<&FlowToken.Vault{FungibleToken.Receiver}>(from: /public/flowTokenReceiver) == nil {
            let flowVault <- FlowToken.createEmptyVault()
            self.account.save(<- flowVault, to: /storage/flowTokenVault)
        }

        if self.account.borrow<&BloctoToken.Vault{FungibleToken.Receiver}>(from: BloctoToken.TokenPublicReceiverPath) == nil {
            let bltVault <- BloctoToken.createEmptyVault()
            self.account.save(<- bltVault, to: BloctoToken.TokenStoragePath)
        }

        if self.account.borrow<&TeleportedTetherToken.Vault{FungibleToken.Receiver}>(from: TeleportedTetherToken.TokenPublicReceiverPath) == nil {
            let tUSDTVault <- TeleportedTetherToken.createEmptyVault()
            self.account.save(<- tUSDTVault, to: TeleportedTetherToken.TokenStoragePath)
        }
    }

    // Script
    pub fun getWaitingIndex(hostAddress: Address): UInt32? {
        return compositionMatcher.getWaitingIndex(hostAddress: hostAddress)
    }
    pub fun getRandomWaitingIndex(): UInt32? {
        return compositionMatcher.getRandomWaitingIndex()
    }

    // Transaction
    pub fun register(
        host: AuthAccount,
        eachBets: @[FungibleToken.Vault],
    ) {
        compositionMatcher.register(host: host)

        let composition <- Composition(
            contractAccount: getAccount(self.account.address)
            totalRound: 2,
            eachBets: eachBets)

        // Create a new Gomoku and put it in storage
        host.save(<- composition, to: CollectionStoragePath)

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        host.link<&PublicCompositioning>(
            self.CollectionStoragePath,
            target: self.CollectionPublicPath
        )

        emit CompositionCreated(
            host: Address,
            currency: String,
            totalBets: UFix64)
    }

    pub fun matchOpponent(
        index: UInt32, 
        challenger: AuthAccount
    ): Bool {
        if let matchedHost = compositionMatcher.match(index: index, challenger: challenger) {
            let currency = composition.getBetCurrency()
            let allBets = composition.getAllBets()

            let capability = account.getCapability(self.CollectionStoragePath)
            let collectionRef = capability.borrow<&PublicCompositioning>()
            collectionRef.match(challenger: challenger)

            emit CompositionMatched(
                host: matchedHost,
                challenger: challenger,
                totalRound: 2,
                currency: currency,
                totalOpeningBets: allBets)
        } else {
            panic("Match failed, please try again.")
        }
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

    pub enum StoneLocation: UInt8 {

        pub let x: UInt8
        pub let y: UInt8

        init(x: UInt8, y: UInt8) {
            self.x = x
            self.y = y
        }

        pub fun key(): String {
            return x.toString().concat(",").concat(y.toString())
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
            return location.key()
        }
    }

    pub resource interface PublicCompositioning {
        // Script
        pub fun getTotalBets(round: UInt8): UFix64
        pub fun getBetCurrency(): String

        // Transaction
        pub fun match(challenger: AuthAccount)

        pub fun switchRound(nextRoundBet: UFix64)
    }

    pub resource interface PrivateCompositioning {
        access(contract) fun activateRegistration()
        access(contract) fun inactivateRegistration()

        access(contract) fun activateMatching()
        access(contract) fun inactivateMatching()
    }

    pub resource Composition:
        PublicCompositioning,
        PrivateCompositioning
    {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        pub let totalRound: UInt8
        pub var currentRound: UInt8

        pub var openingBets: @[FungibleToken.Vault]

        priv var compositionContractAccount: PublicAccount
        priv var challenger: Address?
        priv var raisedBets: @[[FungibleToken.Vault]]
        priv var steps: @[[Stone]]
        priv var locationStoneMap: {String:@Stone}

        // timeout of block height
        pub var latestBlockHeight: UFix64
        pub var blockHeightTimeout: UFix64

        init(
            contractAccount: PublicAccount,
            totalRound: UInt8,
            openingBets: @[FungibleToken.Vault]
        ) {
            pre {
                totalRound == 2: "Total round should be 2 and take turns to make first move (black stone) for fairness."
                Int(totalRound) == openingBets.length: "Total round should be equal to openingBets length."
            }

            self.StoragePath = /storage/gomokuCollection
            self.PublicPath = /public/gomokuCollection

            self.compositionContractAccount = contractAccount
            self.totalRound = totalRound
            self.currentRound = 0
            self.openingBets <- openingBets
            self.raisedBets <- []
            self.steps <- []
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
                self.raisedBets.append([])
                self.steps.append([])
            }
            self.latestBlockHeight = getCurrentBlock().height
            self.blockHeightTimeout = 60 * 60 * 24 * 7
        }

        // Script
        pub fun getBets(round: UInt8): UFix64 {
            pre {
                round < self.totalRound - 1: "Input round (start from 0) should be less than or equal to total rounds."
            }
            return self.openingBets[round].balance + self.raisedBets[round].balance
        }

        pub fun getAllBets(): UFix64 {
            var sum: UFix64 = 0
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
            } else {
                panic("Currency can't be identify.")
            }
        }

        pub fun getTimeout(): UFix64 {
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
            // todo add raised bet
        }

        priv fun verifyAndStoreStone(stone: @Stone) {
            pre {
                self.steps.length == 2: "Steps length should be 2."
                self.currentRound <= 1: "Composition only has 2 round each."
            }
            let roundSteps = self.steps[self.currentRound]
            if self.locationStoneMap[stone.key()] == nil {
                if roundSteps.length % 2 == 0 {
                    // black stone move
                    assert(stone.color == StoneColor.black, message: "It should be black side's move.")
                    
                } else {
                    // white stone move
                    assert(stone.color == StoneColor.white, message: "It should be white side's move.")

                }  
            } else {
                panic("This place had been taken.")
            }

        }

        pub fun switchRound(nextRoundBet: UFix64) {
            pre {
                self.totalRound - 1 > self.currentRound: "This is already the final round."
                self.totalRound - 1 >= self.currentRound + 1: "Next round should not over totalRound."
            }
            post {
                self.openingBet.length == Int(self.currentRound) + 1: "Count of opening bet should equal to round current round."
            }
            self.currentRound = self.currentRound + 1
            self.openingBet.append(nextRoundBet)
        }

        destroy() {
            for openingBet in self.openingBets {
                if let flowVault = firstOpeningBet as? @FlowToken.Vault {
                    let capability = self.compositionContractAccount.getCapability(/public/flowTokenReceiver)
                    let flowVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    flowVaultReference.deposit(flowVault)
                } else if let bltVault = firstOpeningBet as? @BloctoToken.Vault {
                    let capability = self.compositionContractAccount.getCapability(BloctoToken.TokenPublicReceiverPath)
                    let bltVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    bltVaultReference.deposit(bltVault)
                } else if let tUSDTVault = firstOpeningBet as? @TeleportedTetherToken.Vault {
                    let capability = self.compositionContractAccount.getCapability(TeleportedTetherToken.TokenPublicReceiverPath)
                    let tUSDTVaultReference = capability.borrow() ?? panic("Could not borrow a reference to the hello capability")
                    tUSDTVaultReference.deposit(tUSDTVault)
                } else {
                    break
                }
                deposit <- openingBet.withdraw(amount: openingBet.balance)
                self.openingBets.withdraw(amount: )
            }
            destroy self.openingBets
            destroy self.raisedBets
            destroy self.steps
        }

    }

}