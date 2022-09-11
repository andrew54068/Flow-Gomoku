import Gomoku from 0xGOMOKU_ADDRESS

pub fun main(index: UInt32): [Address] {
  return Gomoku.getParticipants(by: index)
}