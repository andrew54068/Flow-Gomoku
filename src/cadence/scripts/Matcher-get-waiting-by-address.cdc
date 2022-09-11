import MatchContract from 0xMATCH_CONTRACT_ADDRESS

pub fun main(address: Address): [UInt32] {
  return MatchContract.getWaiting(by: address)
}