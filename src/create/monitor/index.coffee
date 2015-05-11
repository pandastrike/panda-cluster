#===============================================================================
# panda-cluster - Create - Monitor
#===============================================================================
# During cluster creation, this code is used to monitor the status, and to halt
# things if there is an error or deletion (through Huxley or the Console).
{async} = require "fairmont"

{detect, identify} = require "./cluster"
{spot, on_demand, address} = require './instances'

module.exports = async (spec, aws) ->
  # Detect when the cluster successfully deploys or fails.
  yield detect spec, aws
  console.log "Stack Formation Complete"

  # Retrieve data about the successfully deployed cluster.
  spec = yield identify spec, aws

  # Identify the instances the make up the cluster.
  if spec.cluster.price == 0
    spec.cluster.instances = yield on_demand.get spec, aws  # On Demand Instances
  else
    console.log "Awaiting Spot Request Fulfillment."
    spec.cluster.instances = yield spot.get spec, aws       # Spot Instances

  console.log "Spot Instances Fulfilled."
  # Gather the IP addresses (public and private) on these instances.
  for x in [0...spec.cluster.size]
    spec.cluster.instances[x].ip = yield address spec.cluster.instances[x].id, aws

  for x in spec.cluster.instances
    console.log "Instance:", x.id, x.ip.public, x.ip.private

  return spec
