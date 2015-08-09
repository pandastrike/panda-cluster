{async, sleep, collect, where} = require "fairmont"
{root} = require "../../dns/domain"

module.exports =
  # Detect the successful deployment of a CloudFormation stack.
  detect: async (spec, aws) ->
    # Stay here until CloudFormation reports that everything is okay.  Throw an
    # exepction if anything goes wrong.
    while true
      data = yield aws.cloudformation.describe_stack_events StackName: spec.cluster.name
      resource = data.StackEvents[0].ResourceType
      status = data.StackEvents[0].ResourceStatus

      if resource == "AWS::CloudFormation::Stack" && status == "CREATE_COMPLETE"
        return true
      else if status == "CREATE_FAILED" || status == "DELETE_IN_PROGRESS"
        throw new Error "Stack Creation Failed."
      else
        yield sleep 5000

  # Retrieve data about successfully deployed clusters.
  identify: async (spec, aws) ->
    spec.cluster.vpc =
      id: null
      subnet: id: null

    # Subnet ID:  We can use the CloudFormation stack name to query AWS for the physical ID.
    params =
      StackName: spec.cluster.name
      LogicalResourceId: "ClusterSubnet"

    data = yield aws.cloudformation.describe_stack_resources params
    spec.cluster.vpc.subnet.id = data.StackResources[0].PhysicalResourceId

    # VPC ID: Also tagged with the stack name.
    params = Filters: [
      Name: "tag:Name"
      Values: [ spec.cluster.name ]
    ]

    data = yield aws.ec2.describe_vpcs params
    spec.cluster.vpc.id = data.Vpcs[0].VpcId

    # Get the HostedZoneID for the public hosted zone.  We can look it up by the
    # name because public domains must be unique.
    zone = root spec.cluster.dns.public.name
    zones = yield aws.route53.list_hosted_zones {}
    spec.cluster.dns.public.id = (collect where {Name: zone}, zones.HostedZones)[0].Id

    return spec
