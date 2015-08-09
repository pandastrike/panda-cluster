#===============================================================================
# panda-cluster - ECS
#===============================================================================
# This file coordinates the allocation within Amazon's EC2 Container Service.
{async, sleep} = require "fairmont"

# Return a library of functions to manipulate ECS resources.
module.exports =
  cluster: require "./cluster"
  instance: require "./instance"
