#===============================================================================
# panda-cluster - Subnet
#===============================================================================
# This file coordinates AWS Subnet management for VPCs.
{async, sleep} = require "fairmont"

# Return a library of functions that allow us to manage Subnets.
module.exports =
  create: async (spec, aws) ->
    params =
      CidrBlock: "10.0.0.0/16"  # TODO: Make this configurable
      VpcId: spec.cluster.vpc.id

    data = yield aws.ec2.create_subnet params
    spec.cluster.vpc.subnet = {}
    spec.cluster.vpc.subnet.id = data.Subnet.SubnetId
    return spec

  # Wait for the subnet to be "available".
  wait: async (spec, aws) ->
    params = SubnetIds: [ spec.cluster.vpc.subnet.id ]

    while true
      data = aws.ec2.describe_subnets params
      if data.Subnets[0].State == "available"
        return
      else
        yield sleep 5000
