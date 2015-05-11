#===============================================================================
# panda-cluster - Create - Monitor - Instances
#===============================================================================
# This code pulls data on individual instances.
{async, collect, project, map, sleep} = require "fairmont"

module.exports =
  on_demand:
    # When more expensive on-demand instances are used, they start right away.
    # We just need to query on the stack name and pull active instances.
    get: async (spec, aws) ->
      params = Filters: [
        Name: "tag:aws:cloudformation:stack-name"
        Values: [ spec.cluster.name ] # Only instances within our stack.
      ,
        Name: "instance-state-code"
        Values: [ "16" ] # Only examine running instances.
      ]

      data = yield aws.ec2.describe_instances params
      identify = (x) -> id: x.InstanceId
      return collect map identify, data.Reservations[0].Instances


  spot:
    # Spot Instances go through a lifecycle.  Poll until they have been fulfilled.
    get: async (spec, aws) ->
      params = Filters: [
        Name: "network-interface.subnet-id"
        Values: [spec.cluster.subnet_id]
      ]

      is_active = (x) -> x == "active"
      is_failed = (x) -> x == "closed" || x == "failed" || x == "canceled"
      identify = (x) -> id: x.InstanceId

      while true
        {SpotInstanceRequests} = yield aws.ec2.describe_spot_instance_requests params
        states = collect project "State", SpotInstanceRequests
        success = collect map is_active, states
        failure = collect map is_failed, states

        if states.length == 0
          yield sleep 5000   # Request has yet to be created.
        else if true in failure
          throw new Error "Spot Request was not successfully fulfilled."
        else if false !in success
          # *All* spot instances are online and ready.
          return collect map identify, SpotInstanceRequests
        else
          yield sleep 5000 # Request is pending.


  # Return the public and private facing IP address of a single instance.
  address: async (id, aws) ->
    params = Filters: [
      Name: "instance-id"
      Values: [ id ]
    ]

    data = yield aws.ec2.describe_instances params
    return {
      public: data.Reservations[0].Instances[0].PublicIpAddress
      private: data.Reservations[0].Instances[0].PrivateIpAddress
    }
