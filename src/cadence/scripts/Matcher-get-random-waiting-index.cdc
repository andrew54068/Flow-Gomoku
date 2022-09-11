import MatchContract from 0xMATCH_CONTRACT_ADDRESS

pub fun main(): UInt32? {
  return MatchContract.getRandomWaitingIndex()
}