#===============================================================================
# panda-cluster - SecurityGroups
#===============================================================================
# This file coordinates AWS SecurityGroups management for VPCs.
{async} = require "fairmont"

# Return a library of functions that allow us to manage SecurityGroups.
module.exports =
  create: async (spec, aws) ->
    params =
      Description: "SecurityGroup for Huxley cluster #{spec.cluster.name}"
      GroupName: "Huxley #{spec.cluster.name}"
      VpcId: spec.cluster.vpc.id

    data = yield aws.ec2.create_security_group params
    spec.cluster.vpc.sg = {}
    spec.cluster.vpc.sg.id = data.GroupId
    return spec

  rules:
    create: async (spec, aws) ->

    delete: async (spec, aws) ->
