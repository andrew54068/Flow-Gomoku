import Gomoku from "./Gomoku.cdc"

pub fun main(index: UInt32): [Address] {
  return Gomoku.getParticipants(by: index)
}