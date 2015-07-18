# Spot Instances
#===============================================================================
# This file coordinates allocation of EC2 spot instances, which can be used to
# save money and/or run tests.  Their API is slightly different, so they get
# their own functions.
{async, empty, sleep, collect, project, map, remove} = require "fairmont"
ami = require "./ami"

module.exports =
  # Create the specifed EC2 instances. id is a Huxley group ID.
  create: async (id, spec, aws) ->
    # Establish a place to store details about these instances. id is a Huxley group ID.
    group = spec.cluster.resources[id]
    group.instances = []
    group.instances.push {} for x in [0...group.size]

    # Create a bash string that loads the desired SSH keys into the instance.
    userdata = "#!/bin/bash \necho \'"
    userdata += "#{key}\n" for key in spec.public_keys
    userdata += "\' > /root/.ssh/authorized_keys"

    # Place the create call to AWS and gather the results.
    params =
      SpotPrice: group.price
      InstanceCount: group.size
      Type: "one-time"
      LaunchSpecification:
        EbsOptimized: false    # TODO: Make this configurable.
        ImageId: ami.get spec.aws.region
        InstanceType: group.type
        KeyName: spec.aws.key_name
        Monitoring:
          Enabled: true  # TODO: Make this configurable.
        Placement:
          AvailabilityZone: spec.aws.availability_zone
        SecurityGroupIds: [ spec.cluster.sg.id ]
        SubnetId: spec.cluster.subnet.id
        UserData: userdata

    {SpotInstanceRequests} = yield aws.request_spot_instances params
    group.instances[x].id = SpotInstanceRequests[x].SpotInstanceRequestId for x in [0...Instances.length]
    group.status = "allocating"
    spec.cluster.resources[id] = group
    return spec

  # Check for Spot Request fulfillment.  id is a Huxley group ID.
  confirm: async (id, spec, aws) ->
    params = SpotInstanceRequestIds: collect project "id", spec.cluster.resources[id]

    is_active = (x) -> x == "active"
    is_failed = (x) -> x == "closed" || x == "failed" || x == "cancelled"
    identify = (x) ->
      spot_id: x.SpotInstanceRequestId
      id: x.InstanceId

    while true
      {SpotInstanceRequests} = yield aws.ec2.describe_spot_instance_requests params
      states = collect project "State", SpotInstanceRequests
      success = collect map is_active, states
      failure = collect map is_failed, states

      if empty states
        yield sleep 5000   # Request has yet to be created.
      else if true in failure
        throw new Error "Spot Request was not successfully fulfilled."
      else if false !in success
        # *All* spot instances are fulfilled.  Return their new EC2 instance IDs
        group = spec.cluster.resources[id]
        legend = collect map identify, SpotInstanceRequests

        for i in [0...group.instances.length]
          for j in [0...legend.length]
            if group.instances[i].id == legend[j].spot_id
              group.instances[i].id = legend[j].id
              remove legend, j
              break

        spec.cluster.resources[id] = group
        return spec

      else
        yield sleep 5000 # Request is pending.
