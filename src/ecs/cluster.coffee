#===============================================================================
# panda-cluster - ECS Cluster
#===============================================================================
# This file coordinates the allocation of clusters in Amazon's EC2 Container Service.
{async, sleep} = require "fairmont"

module.exports =
  # Establish an ECS cluster.
  build: async (spec, aws) ->
    params = clusterName: spec.cluster.name

    data = yield aws.ecs.create_cluster params
    spec.cluster.cloud = {}
    spec.cluster.cloud.id = data.cluster.clusterArn
    return spec

  # Wait for the ECS cluster to be capable of accepting deployments.
  wait: async (spec, aws) ->
    params = clusters: [ spec.cluster.name ]

    while true
      data = yield aws.ecs.describe_clusters params
      if data.clusters[0].status == "ACTIVE"
        return true  # Cluster is ready
      else
        yield sleep 5000  # Needs more time.
