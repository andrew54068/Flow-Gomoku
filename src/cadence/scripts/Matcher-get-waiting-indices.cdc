import MatchContract from "./MatchContract.cdc"

pub fun main(): [UInt32] {
  return MatchContract.waitingIndices
}