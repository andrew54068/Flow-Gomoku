import Crypto

pub contract MatchContract {

    pub struct Matcher: Matching {
        access(account) var registerActive: Bool
        access(account) var matchActive: Bool

        // latest not used yet index
        pub var nextIndex: UInt32
        access(account) let addressGroupMap: { String: { MatchStatus: [UInt32] } }
        access(account) let indexAddressMap: { UInt32: { MatchRole: Address } }
        access(account) let waitingIndices: [UInt32]
        access(account) let matchedIndices: [UInt32]

        pub init() {
            self.registerActive = false
            self.matchActive = false
            self.nextIndex = 0
            self.addressGroupMap = {}
            self.indexAddressMap = {}
            self.waitingIndices = []
            self.matchedIndices = []
        }

        // Script

        // Return oldest waiting index as well as first index of waiting group of specific address.
        pub fun getWaitingIndex(hostAddress: Address): UInt32? {
            let key = hostAddress.toString().toLower()
            let matchGroups = self.addressGroupMap[key] ?? {}
            let waitingGroup = matchGroups[MatchStatus.waiting] ?? []
            if waitingGroup.length > 0 {
                return waitingGroup[0]
            } else {
                return nil
            }
        }

        // Return oldest waiting index as well as first index of waitingIndices.
        pub fun getRandomWaitingIndex(): UInt32? {
            if self.waitingIndices.length > 0 {
                for waitingIndex in self.waitingIndices {
                    assert(self.indexAddressMap.keys.contains(waitingIndex), message: "IndexAddressMap should contain index ".concat(waitingIndex.toString()))
                    if let addressGroups = self.indexAddressMap[waitingIndex] {
                        if addressGroups[MatchRole.challenger] == nil {
                            return waitingIndex
                        } else {
                            continue
                        }
                    }
                }
                return nil
            } else {
                return nil
            }
        }

        // Transaction

        // Register a waiting match.
        pub fun register(host: AuthAccount) {
            pre {
                self.registerActive: "Registration is not active."
            }
            let hostAddress = host.address
            let key = hostAddress.toString().toLower()

            let matchGroups = self.addressGroupMap[key] ?? {}
            let waitingGroup: [UInt32] = matchGroups[MatchStatus.waiting] ?? []

            var currentIndex = self.nextIndex

            waitingGroup.append(currentIndex)
            matchGroups[MatchStatus.waiting] = waitingGroup
            self.addressGroupMap[key] = matchGroups

            self.indexAddressMap[currentIndex] = { MatchRole.host: hostAddress }
            self.waitingIndices.append(currentIndex)

            if currentIndex == UInt32.max {
                // Indices is using out.
                self.registerActive = false
                return 
            } else {
                self.nextIndex = currentIndex + 1
            }
        }

        // Must match with specific index in case host register slightly before.
        pub fun match(
            index: UInt32,
            challenger: AuthAccount, 
            host: AuthAccount
        ): Bool {
            pre {
                self.matchActive: "Matching is not active."
            }
            let hostKey = host.address.toString().toLower()
            let matchGroups = self.addressGroupMap[hostKey] ?? {}
            let waitingGroup: [UInt32] = matchGroups[MatchStatus.waiting] ?? []
            assert(waitingGroup.length > 0, message: host.address.toString().concat("'s waiting group length should over 0"))
            assert(waitingGroup.contains(index), message: host.address.toString().concat(" not contain index: ").concat(index.toString()))

            if let firstIndex: Int = waitingGroup.firstIndex(of: index) {
                let matchIndex = waitingGroup.remove(at: firstIndex)
                assert(matchIndex == index, message: "Match index not equal.")
                let matchedGroup: [UInt32] = matchGroups[MatchStatus.matched] ?? []
                matchedGroup.append(matchIndex)
                matchGroups[MatchStatus.matched] = matchedGroup
                self.addressGroupMap[hostKey] = matchGroups

                let addressGroup = self.indexAddressMap[matchIndex] ?? {}
                assert(addressGroup[MatchRole.host] != nil, message: "Host should exist in indexAddressMap before matching.")
                assert(addressGroup[MatchRole.host] == host.address, message: "Host should be ".concat(host.address.toString()).concat("."))
                assert(addressGroup[MatchRole.challenger] == nil, message: "Challenger should not exist in indexAddressMap before matching.")
                addressGroup[MatchRole.challenger] = challenger.address
                self.indexAddressMap[matchIndex] = addressGroup
                assert(self.indexAddressMap[matchIndex]![MatchRole.challenger] == challenger.address, message: "Challenger should not exist in indexAddressMap before matching.")

                assert(self.waitingIndices.contains(matchIndex), message: "WaitingIndices should include ".concat(matchIndex.toString()).concat(" before matched."))
                assert(self.matchedIndices.contains(matchIndex) == false, message: "MatchedIndices should not include ".concat(matchIndex.toString()).concat(" before matched."))
                if let waitingIndex = self.waitingIndices.firstIndex(of: matchIndex) {
                    let matchedIndex = self.waitingIndices.remove(at: waitingIndex)
                    self.matchedIndices.append(matchedIndex)
                } else {
                    panic("MatchIndex ".concat(matchIndex.toString()).concat(" should be found in waitingIndices"))
                }
                self.matchedIndices.append(matchIndex)
                assert(self.waitingIndices.contains(matchIndex), message: "WaitingIndices should not include ".concat(matchIndex.toString()).concat(" after matched."))
                assert(self.matchedIndices.contains(matchIndex), message: "MatchedIndices should include ".concat(matchIndex.toString()).concat(" after matched."))
                return true
            } else {
                return false
            }
        }

    }

    pub struct interface Matching {

        // Control flags
        access(account) var registerActive: Bool
        access(account) var matchActive: Bool

        pub var nextIndex: UInt32
        access(account) let addressGroupMap: { String: { MatchStatus: [UInt32] } }
        access(account) let indexAddressMap: { UInt32: { MatchRole: Address } }
        access(account) let waitingIndices: [UInt32]
        access(account) let matchedIndices: [UInt32]

        // Script
        pub fun getWaitingIndex(hostAddress: Address): UInt32?
        pub fun getRandomWaitingIndex(): UInt32?

        // Transaction
        pub fun register(host: AuthAccount)

        pub fun match(
            index: UInt32, 
            challenger: AuthAccount,
            host: AuthAccount
        ): Bool

    }

    pub enum MatchStatus: UInt8 {
        pub case waiting
        pub case matched
    }

    pub enum MatchRole: UInt8 {
        pub case host
        pub case challenger
    }

}