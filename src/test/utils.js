import {
  getAccountAddress,
  deployContractByName
} from "@onflow/flow-js-testing";

export const expectContractDeployed = (deploymentResult) => {
  expect(deploymentResult.statusString).toBe('SEALED')
  let event = deploymentResult.events.filter(value => value.type == 'flow.AccountContractAdded')
  expect(event.length).toBe(1)
}

export const deployMatcher = async () => {
  const to = await getAccountAddress("Alice")

  // We assume there is a file on "../cadence/contracts/MatchContract.cdc" path
  const name = "MatchContract"

  const [deploymentResult, error] = await deployContractByName({ to, name })
  expect(error).toBeNull()
  expect(deploymentResult.statusString).toBe('SEALED')
  let event = deploymentResult.events.filter(value => value.type == 'flow.AccountContractAdded')
  expect(event.length).toBe(1)
  expectContractDeployed(deploymentResult)
}

export const deployGomokuType = async () => {
  const to = await getAccountAddress("Alice")

  // We assume there is a file on "../cadence/contracts/GomokuType.cdc" path
  const name = "GomokuType"

  const [deploymentResult, error] = await deployContractByName({ to, name })
  expect(error).toBeNull()
  expect(deploymentResult.statusString).toBe('SEALED')
  let event = deploymentResult.events.filter(value => value.type == 'flow.AccountContractAdded')
  expect(event.length).toBe(1)
  expectContractDeployed(deploymentResult)
}

export const deployContract = async (name) => {
  const to = await getAccountAddress("Alice")

  const [deploymentResult, error] = await deployContractByName({ to, name })
  expect(error).toBeNull()
  expect(deploymentResult.statusString).toBe('SEALED')
  let event = deploymentResult.events.filter(value => value.type == 'flow.AccountContractAdded')
  expect(event.length).toBe(1)
  expectContractDeployed(deploymentResult)
}