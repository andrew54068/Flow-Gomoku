import Gomoku from "../contracts/Gomoku.cdc"

pub fun main(index: UInt32): UFix64? {
  return Gomoku.getOpeningBet(by: index)
}