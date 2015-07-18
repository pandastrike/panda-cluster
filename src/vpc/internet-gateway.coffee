#===============================================================================
# panda-cluster - InternetGateway
#===============================================================================
# This file coordinates AWS InternetGateway management for VPCs.
{async} = require "fairmont"

# Return a library of functions that allow us to manage Gateways.
module.exports =
  attach: async (spec, aws) ->
    params =
      InternetGatewayId: spec.cluster.vpc.gateway_id
      VpcId: spec.cluster.vpc.id

    yield aws.ec2.attach_internet_gateway params


  create: async (spec, aws) ->
    data = yield aws.ec2.create_internet_gateway {}
    spec.cluster.vpc.gateway = {}
    spec.cluster.vpc.gateway.id = data.InternetGateway.InternetGatewayId
    return spec
