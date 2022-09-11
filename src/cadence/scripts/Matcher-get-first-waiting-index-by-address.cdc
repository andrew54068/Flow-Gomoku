import MatchContract from 0xMATCH_CONTRACT_ADDRESS

pub fun main(hostAddress: Address): UInt32? {
  return MatchContract.getFirstWaitingIndex(hostAddress: hostAddress)
}