import MatchContract from "../contracts/MatchContract.cdc"

pub fun main(hostAddress: Address): UInt32? {
  return MatchContract.getFirstWaitingIndex(hostAddress: hostAddress)
}