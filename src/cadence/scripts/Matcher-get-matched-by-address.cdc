import MatchContract from "../contracts/MatchContract.cdc"

pub fun main(address: Address): [UInt32] {
  return MatchContract.getMatched(by: address)
}