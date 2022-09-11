import Gomoku from 0xGOMOKU_ADDRESS

pub fun main(index: UInt32): [UFix64] {
  return [Gomoku.getChallengerOpeningBet(by: index) ?? UFix64(0), Gomoku.getChallengerRaisedBet(by: index) ?? UFix64(0)]
}