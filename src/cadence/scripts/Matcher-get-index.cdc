import MatchContract from "../contracts/MatchContract.cdc"

pub fun main(): UInt32 {
  return MatchContract.getNextIndex()
}