import Gomoku from "../contracts/Gomoku.cdc"
import GomokuType from "../contracts/GomokuType.cdc"

pub fun main(index: UInt32, roundIndex: UInt8): GomokuType.Role? {
  if let compositionRef = Gomoku.getCompositionRef(by: index) as &Gomoku.Composition? {
    return compositionRef.getRoundWinner(by: roundIndex)
  } else {
    return nil
  }
}