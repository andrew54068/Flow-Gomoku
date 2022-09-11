import Gomoku from 0xGOMOKU_ADDRESS

pub fun main(index: UInt32): UFix64? {
  return Gomoku.getValidBets(by: index)
}