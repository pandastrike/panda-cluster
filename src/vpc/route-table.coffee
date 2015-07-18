#===============================================================================
# panda-cluster - Route Table
#===============================================================================
# This file coordinates AWS Route Table management for VPCs.
{async, sleep} = require "fairmont"

# Return a library of functions that allow us to manage Route Tables.
module.exports =
  attach: async (spec, aws) ->
    params =
      RouteTableId: spec.cluster.vpc.table.id
      SubnetId: spec.cluster.vpc.subnet.id

    data = aws.ec2.associate_route_table params


  create: async (spec, aws) ->
    params = VpcId: spec.cluster.vpc.id
    data = yield aws.ec2.create_route_table params
    spec.cluster.vpc.table = {}
    spec.cluster.vpc.table.id = data.RouteTable.RouteTableId
    return spec

  # Stay here until AWS reports that the RouteTable is "active".
  wait: async (spec, aws) ->
    params = RouteTableIds: [ spec.cluster.vpc.table.id ]

    while true
      data = yield aws.ec2.describe_route_tables params
      if data.RouteTables.Routes[0].State == "active"
        return
      else
        yield sleep 5000
