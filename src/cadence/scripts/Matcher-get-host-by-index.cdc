import MatchContract from 0xMATCH_CONTRACT_ADDRESS

pub fun main(index: UInt32): Address? {
  return MatchContract.getHostAddress(by: index)
}