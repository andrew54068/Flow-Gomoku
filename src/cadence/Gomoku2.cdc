import Crypto
import MatchContract from 0x01
import NonFungibleToken from 0x02
import FungibleToken from 0x03

pub contract Gomoku {

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

    pub resource interface PublicCompositioning {
        pub fun totalBets(round: UInt8): UFix64
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
        access(account) let compositionMatcher: AnyStruct{MatchContract.Matching}

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
            self.compositionMatcher = MatchContract.Matcher()
            self.totalRound = totalRound
            self.currentRound = 0
            self.winCondition = winCondition
            self.openingBet = [bet]
            self.raisedBets = []
            self.steps <- []
        }

        // Matching
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