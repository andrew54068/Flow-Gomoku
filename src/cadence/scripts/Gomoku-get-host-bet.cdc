import Gomoku from 0xGOMOKU_ADDRESS

pub fun main(index: UInt32): [UFix64] {
  return [Gomoku.getHostOpeningBet(by: index) ?? UFix64(0), Gomoku.getHostRaisedBet(by: index) ?? UFix64(0)]
}