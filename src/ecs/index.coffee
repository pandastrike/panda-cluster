#===============================================================================
# panda-cluster - ECS
#===============================================================================
# This file coordinates the allocation of Amazon's EC2 Container Service.
{async, sleep} = require "fairmont"

# Return a library of functions that handle cluster allocation.
module.exports =

  # Establish an ECS cluster.
  build: async (spec, aws) ->
    params = clusterName: spec.cluster.name

    data = yield aws.ecs.create_cluster params
    spec.cluster.cloud = {}
    spec.cluster.cloud.id = data.cluster.clusterArn
    return spec
