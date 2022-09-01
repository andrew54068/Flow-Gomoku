import FlowToken from "../contracts/FlowToken.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"

pub fun main(address: Address): UFix64 {
  let flowValutRef = getAccount(address)
    .getCapability<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance)
    .borrow() ?? panic("Could not borrow a reference to the Flow token receiver capability")
  return flowValutRef.balance
}