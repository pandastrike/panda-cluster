module.exports =
  # Create an empty VPC.
  create: async (spec, aws) ->
    params = CidrBlock: "10.0.0.0/16"  # TODO: Make this configurable.
    data = yield aws.ec2.create_vpc params
    spec.cluster.vpc = {}
    spec.cluster.vpc.id = data.VpcId
    return spec

  # Stay here until AWS reports that the VPC is "available", ready for configuration.
  wait: async (spec, aws) ->
    params = VpcIds: [ spec.cluster.vpc.id ]

    while true
      data = yield aws.ec2.describe_vpcs params
      if data.Vpcs[0].State == "available"
        return
      else
        yield sleep 5000
