import GomokuResult from 0xGOMOKU_RESULT_ADDRESS

pub fun main(address: Address, index: UInt32): &GomokuResult.ResultToken? {
  let resultCollectionRef = getAccount(address)
      .getCapability<&GomokuResult.ResultCollection>(GomokuResult.CollectionPublicPath)
      .borrow() ?? panic("Could not borrow a reference to the address gomoku result collection ref.") 
  return resultCollectionRef.borrow(id: index) as &GomokuResult.ResultToken?
}