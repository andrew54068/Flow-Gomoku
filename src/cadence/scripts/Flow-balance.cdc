import FlowToken from 0xFLOW_TOKEN_ADDRESS
import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS

pub fun main(address: Address): UFix64 {
  let flowValutRef = getAccount(address)
    .getCapability<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance)
    .borrow() ?? panic("Could not borrow a reference to the Flow token receiver capability")
  return flowValutRef.balance
}