#===============================================================================
# panda-cluster - ECS Cluster
#===============================================================================
# This file coordinates the allocation of clusters in Amazon's EC2 Container Service.
{async, sleep} = require "fairmont"

module.exports =
  launch: async () ->
