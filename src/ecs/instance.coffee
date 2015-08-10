#===============================================================================
# panda-cluster - ECS Instances
#===============================================================================
# This file coordinates the allocation of instances within our ECS cluster.
{async, collect, project, map, sleep, empty} = require "fairmont"

module.exports =
  # Create one or more EC2 instance and launch it into the ECS cluster.
  create: async (config, spec, aws) ->
    params =
      ImageId: require("./ami")[spec.aws.region]
      MaxCount: config.count
      MinCount: config.count
      InstanceType: config.type
      KeyName: spec.aws.key_name
      Monitoring: Enabled: true
      UserData: config.user_data
      Tags: config.tags
      NetworkInterfaces: [
        {
          AssociatePublicIpAddress: true
          DeleteOnTermination: true
          SubnetId: spec.cluster.vpc.subnet.id
          Groups: [ spec.cluster.sg.id ]
        }
      ]

    params.Placement = AvailabilityZone: config.availability_zone if config.availability_zone

    data = yield aws.ec2.run_instances params
    instances = collect project "InstanceId", data.Instances

    # Wait for all these instances to be online.
    params = Filters: [
      Name: "instance-id"
      Values: instances
    ]

    is_active = (x) -> Number(x.code) == 16
    is_failed = (x) -> Number(x.code) > 16
    identify = (x) ->
      id: x.InstanceId
      ip:
        public: x.PublicIpAddress
        private: x.PrivateIpAddress

    while true
      data = yield aws.ec2.describe_instances params
      states = collect project "State", data.Reservations[0].Instances
      success = collect map is_active, states
      failure = collect map is_failed, states

      if true in failure
        throw new Error "Instance(s) were not successfully activated."
      else if false !in success
        # *All* instances are online and ready.
        return collect map identify, data.Reservations[0].Instances
      else
        yield sleep 5000 # Request is pending.


  delete: async () ->
