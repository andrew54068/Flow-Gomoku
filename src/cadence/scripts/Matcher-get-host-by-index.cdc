import MatchContract from "../contracts/MatchContract.cdc"

pub fun main(index: UInt32): Address? {
  return MatchContract.getHostAddress(by: index)
}