import MatchContract from "./MatchContract.cdc"

pub fun main(hostAddress: Address): UInt32? {
  return MatchContract.getWaitingIndex(hostAddress: hostAddress)
}