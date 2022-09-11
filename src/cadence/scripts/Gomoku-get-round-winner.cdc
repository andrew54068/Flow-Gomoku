import Gomoku from 0xGOMOKU_ADDRESS
import GomokuType from 0xGOMOKU_TYPE_ADDRESS

pub fun main(index: UInt32, roundIndex: UInt8): GomokuType.Result? {
  if let compositionRef = Gomoku.getCompositionRef(by: index) as &Gomoku.Composition? {
    return compositionRef.getRoundWinner(by: roundIndex)
  } else {
    return nil
  }
}