#===============================================================================
# panda-cluster - Create - Monitor
#===============================================================================
# During cluster creation, this code is used to monitor the status, and to halt
# things if there is an error or deletion (through Huxley or the Console).
{async} = require "fairmont"

{detect, identify} = require "./cluster"
{spot, on_demand, address} = require './instances'
{update} = require "../../huxley"

module.exports = async (spec, aws) ->
  # Detect when the cluster successfully deploys or fails.
  yield detect spec, aws
  yield update spec, "starting", "Stack Formation Complete"

  # Retrieve data about the successfully deployed cluster.
  spec = yield identify spec, aws

  # Identify the instances the make up the cluster.
  if spec.cluster.price == 0
    spec.cluster.instances = yield on_demand.get spec, aws  # On Demand Instances
    yield update spec, "starting", "Instances Online"
  else
    yield update spec, "starting", "Awaiting Spot Request Fulfillment."
    spec.cluster.instances = yield spot.get spec, aws       # Spot Instances
    yield update spec, "starting", "Spot Instances Online."

  # # Gather the IP addresses (public and private) on these instances.
  # for x in [0...spec.cluster.size]
  #   spec.cluster.instances[x].ip = yield address spec.cluster.instances[x].id, aws
  #
  # for x in spec.cluster.instances
  #   console.log "Instance:", x.id, x.ip.public, x.ip.private

  return spec
