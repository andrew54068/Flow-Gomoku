import Gomoku from "../contracts/Gomoku.cdc"

pub fun main(index: UInt32): &Gomoku.Composition? {
  return Gomoku.getCompositionRef(by: index)
}