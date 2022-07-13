import MatchContract from "./MatchContract.cdc"

pub fun main(address: Address): [UInt32] {
  return MatchContract.getMatched(by: address)
}