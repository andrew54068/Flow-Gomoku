import Gomoku from 0xGOMOKU_ADDRESS

pub fun main(index: UInt32, round: UInt8): [Gomoku.StoneData] {
  let compositionRef = Gomoku.getCompositionRef(by: index) ?? panic("Composition ref not found.")
  return compositionRef.getStoneData(for: round)
}