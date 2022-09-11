import Gomoku from 0xGOMOKU_ADDRESS

pub fun main(index: UInt32): &Gomoku.Composition? {
  return Gomoku.getCompositionRef(by: index)
}