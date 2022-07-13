import MatchContract from "./MatchContract.cdc"

pub fun main(index: UInt32): Address? {
  return MatchContract.getHostAddress(by: index)
}