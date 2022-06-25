// import NonFungibleToken from 0x1d7e57aa55817448



pub contract MatchContract {

    pub struct CompositionMatcher: Matcher {
        access(account) let store: { String: { MatchStatus: [AnyStruct{Matchable}] } }
        access(account) let waitingQueue: [AnyStruct{Matchable}]

        pub init() {
            self.store = {}
            self.waitingQueue = []
        }

        pub fun register(authAccount: AuthAccount) {
            let block = getCurrentBlock()
            let address = authAccount.address

            let object = MatchableObject(
                address: address,
                blockHeight: block.height,
                status: MatchStatus.waiting)
            let key = address.toString().toLower()

            let compositionGroups = self.store[key] ?? {}
            let waitingCompositions: [AnyStruct{Matchable}] = compositionGroups[MatchStatus.waiting] ?? []

            // We used address and block height to identify composition, so user can only have one composition per block.
            // Check if composition exist in same block height here.
            if waitingCompositions.length > 0 
                && waitingCompositions[waitingCompositions.length - 1].blockHeight < block.height {
                let matchedCompositions: [AnyStruct{Matchable}] = compositionGroups[MatchStatus.matched] ?? []
                if matchedCompositions.length > 0
                    && matchedCompositions[matchedCompositions.length - 1].blockHeight < block.height {
                    compositionGroups[MatchStatus.waiting] = waitingCompositions.concat([object])
                    self.store[key] = compositionGroups
                    self.waitingQueue.append(object)
                    return
                }
            }
            panic("User can only register once per block, please try again.")
        }

        pub fun getWaitingByAddress(address: Address): AnyStruct{Matchable}? {
            let key = address.toString().toLower()
            let compositionGroups = self.store[key] ?? {}
            if compositionGroups[MatchStatus.waiting].length > 0 {
                return compositionGroups[0]
            } else {
                return nil
            }
        }

        pub fun match(challenger: AuthAccount, host: AuthAccount): Bool {
            let hostKey = host.address.toString().toLower()
            if let compositions = self.store[hostKey] {
                for composition in compositions {
                    if composition.status == MatchStatus.waiting {
                        composition.changeStatus(status: MatchStatus.matched)
                    }
                }
            }
            return 
        }

        pub fun randomMatch(challenger: AuthAccount): Bool {

        }

        priv fun checkExist(
            address: Address,
            blockHeight: UInt64
        ): Bool {
            let key = address.toString().toLower()
            let compositionGroups = self.store[key] ?? {}
            let waitingObjects: [AnyStruct{Matchable}] = compositionGroups[MatchStatus.waiting] ?? []

            if waitingObjects.length > 0 {
                let lastIndex = waitingObjects.length - 1
                if waitingObjects[lastIndex].blockHeight < blockHeight {
                    return false
                }
                waitingObjects[lastIndex]
                && waitingObjects[].blockHeight == blockHeight {
                
            }
            for element in objects {
                if element.address == address 
                    && element.blockHeight == blockHeight {
                    return element
                }
            }
            return nil
        }

        priv fun findByStruct(
            address: Address,
            blockHeight: UInt64,
            status: MatchStatus
        ): AnyStruct{Matchable}? {
            let key = address.toString().toLower()
            let compositionGroups = self.store[key] ?? {}
            let objects: [AnyStruct{Matchable}] = compositionGroups[status] ?? []

            if objects.length > 0
                && objects[0].blockHeight == blockHeight {
                
            }
            for element in objects {
                if element.address == address 
                    && element.blockHeight == blockHeight {
                    return element
                }
            }
            return nil
        }
    }

    pub struct interface Matcher {

        pub let store: {String: [AnyStruct{Matchable}]}

        pub fun register(authAccount: AuthAccount)

        pub fun findByAddress(address: Address): [AnyStruct{Matchable}]

        pub fun match(authAccount: AuthAccount, host: AuthAccount): Bool
        pub fun randomMatch(authAccount: AuthAccount): Bool

    }

    pub struct interface Matchable {
        access(account) fun changeStatus(status: MatchStatus)
        pub let address: Address
        pub let blockHeight: UInt64
        pub var status: MatchStatus
    }

    pub enum MatchStatus: UInt8 {
        pub case waiting
        pub case matched
    }

    pub struct MatchableObject: Matchable {
        pub let address: Address
        pub let blockHeight: UInt64
        pub var status: MatchStatus

        pub init(
            address: Address,
            blockHeight: UInt64,
            status: MatchStatus
        ) {
            self.address = address
            self.blockHeight = blockHeight
            self.status = status
        }

        access(account) fun changeStatus(status: MatchStatus) {
            self.status = status
        }

    }

}

pub contract Gomoku: // NonFungibleToken
    MatchingInterfaces.Matchable {

    pub enum StoneColor: UInt8 {
        // block stone go first
        pub case black
        pub case white
    }

    pub resource Stone {
        pub let color: StoneColor

        init(color: StoneColor) {
            self.color = color
        }
    }

    pub struct interface PublicMatching {

    }

    pub resource interface PublicCompositioning {
        pub fun registration()

        pub fun totalBets(round: UInt8): UFix64
        pub fun switchRound(nextRoundBet: UFix64)
    }

    pub resource interface PrivateCompositioning {

    }

    pub resource Composition:
        PublicMatching,
        PublicCompositioning,
        PrivateCompositioning
    {

        pub let totalRound: UInt8
        pub var currentRound: UInt8

        // How many stone in a row for a win
        pub let winCondition: Int8
        pub let openingBet: [UFix64]

        priv var raisedBets: [UFix64]
        priv var steps: @[[Stone]]

        init(
            totalRound: UInt8,
            winCondition: Int8,
            bet: UFix64
        ) {
            pre {
                winCondition >= 5: "Winning condition (how many in a row) should be greater than or equal to 5."
                totalRound >= 2: "Total round should be at lease 2 and take turn to take first hand (black stone) for fairness."
                totalRound % UInt8(2) == 0: "Total round should be an even number."
            }
            self.totalRound = totalRound
            self.currentRound = 0
            self.winCondition = winCondition
            self.openingBet = [bet]
            self.raisedBets = []
            self.steps <- []
        }

        // Matching
        pub fun registration(authAccount: AuthAccount): String {
            var hashData: [UInt8] = []
            let block: Block = getCurrentBlock()
            hashData = hashData
                .concat(authAccount.address.toBytes())
                .concat(block.height.toBigEndianBytes())
            return HashAlgorithm.SHA3_256.hash(hashData)
        }

        pub fun findMatch(): MatchableObject {

        }

        pub fun totalBets(round: UInt8): UFix64 {
            pre {
                round < self.totalRound - 1: "Input round (start from 0) should be less than or equal to total rounds."
            }
            return self.openingBet[round] + self.raisedBets[round]
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
            destroy self.steps
        }

    }

}