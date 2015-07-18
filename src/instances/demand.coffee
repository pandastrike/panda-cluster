# On-Demand Instances
#===============================================================================
# This file coordinates allocation of On-Demand Instances, the full price version
# that comes online as quickly as possible.  Their API is slightly different from
# Spot Instances, so they get their own functions.
{async} = require "fairmont"
ami = require "./ami"

module.exports =
  # Create the specifed EC2 instances.
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
      ImageId: ami.get spec.aws.region
      MaxCount: group.size
      MinCount: group.size
      InstanceType: group.type
      KeyName: spec.aws.key_name
      SecurityGroupIds: [ spec.cluster.sg.id ]
      SubnetId: spec.cluster.subnet.id
      UserData: userdata
      Placement:
        AvailabilityZone: spec.aws.availability_zone  # TODO: Make this *more* configurable.
        Tenancy: 'default'    # TODO: Make this configurable.
      EbsOptimized: false     # TODO: Make this configurable.
      InstanceInitiatedShutdownBehavior: 'terminate'  # TODO: Make this configurable.
      Monitoring:
        Enabled: true         # TODO: Make this configurable.

    {Instances} = yield aws.ec2.run_instances params
    group.instances[x].id = Instances[x].InstanceId for x in [0...Instances.length]
    group.status = "allocating"
    spec.cluster.resources[id] = group
    return spec


  # Instances don't boot up instantly.  Wait until they are available. id is a Huxley group ID.
  wait: async (id, spec, aws) ->
