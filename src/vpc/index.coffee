#===============================================================================
# panda-cluster - VPC
#===============================================================================
# This file coordinates the allocation of Amazon's Virtual Private Cloud.
{async, sleep} = require "fairmont"

vpc = require "./helpers"
gateway = require "./internet-gateway"
table = require "./route-table"
route = require "./route"
subnet = require "./subnet"
sg = require "./security_group"

# Return a library of functions that handle cluster allocation.  This functionality
# is similar to what AWS does with CloudFormation, but we have finer control.
module.exports =

  # Establish a fully-fledged VPC.  This includes several components, many of which
  # can be created independently and simultaenously, then assembled.
  build: async (spec, aws) ->
    # Start with the base components that can be built independently.
    spec = yield vpc.create spec, aws
    spec = yield gateway.create spec, aws

    # Wait for the VPC to be "available", then attach/create VPC components.
    yield vpc.wait spec, aws
    yield gateway.attach spec, aws
    spec = yield table.create spec, aws
    spec = yield subnet.create spec, aws
    spec = yield sg.create spec, aws

    # Wait for the route table's primary route to be "active", then attach our public route.
    yield table.wait spec, aws
    yield route.create spec, aws

    # Wait for the subnet to be "available", the attach the routetable to it.
    yield subnet.wait spec, aws
    yield table.attach spec, aws


  # Irreversibly destroy the specified VPC.  We must carefully delete all internal
  # components before deleting the remaining, empty VPC.
  destroy: async (spec, aws) ->
