#===============================================================================
# panda-cluster - Route
#===============================================================================
# This file coordinates AWS Route management for RouteTables.
{async} = require "fairmont"

# Return a library of functions that allow us to manage Routes.
module.exports =
  create: async (spec, aws) ->
    # TODO: Make this configurable.  For now, we open access to the public Internet.
    params =
      DestinationCidrBlock: "0.0.0.0/0"
      RouteTableId: spec.cluster.vpc.table.id
      GatewayId: spec.cluster.vpc.gateway.id

    yield aws.ec2.create_route params
