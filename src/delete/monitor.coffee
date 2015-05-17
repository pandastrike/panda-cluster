{async, sleep, collect, where, empty} = require "fairmont"

module.exports =
  # Detect the successful deletion of a CloudFormation stack.
  detect: async (spec, aws) ->
    # Stay here until CloudFormation reports that everything is offline.  Throw an
    # exepction if anything goes wrong.
    while true
      try
        data = yield aws.cloudformation.describe_stack_events StackName: spec.cluster.name
      catch error
        # If we fail to find the stack in AWS, we can assume it's done being deleted.
        # TODO: This is a questionable method...  figure out a better way to do this.
        return true

      resource = data.StackEvents[0].ResourceType
      status = data.StackEvents[0].ResourceStatus

      if resource == "AWS::CloudFormation::Stack" && status == "DELETE_COMPLETE"
        return true
      else if status == "DELETE_FAILED"
        throw new Error "Stack Deletion Failed."
      else
        yield sleep 5000

  # Retrieve data about the requested cluster.
  identify: async (spec, aws) ->
    # VPC ID: We can use the stack name to query AWS for the physical ID.
    params = Filters: [
      Name: "tag:Name"
      Values: [ spec.cluster.name ]
    ]

    data = yield aws.ec2.describe_vpcs params
    if empty data.Vpcs
      spec.cluster.vpc_id = false
      spec.cluster.zones = private: id: false
      return spec
    
    spec.cluster.vpc_id = data.Vpcs[0].VpcId


    # Get the HostedZoneID for the cluster's private hosted zone.  Now that we
    # have the cluster's VPC ID, we can look this up.
    data = yield aws.route53.list_hosted_zones {}
    # Dig the ID out of an array, holding an object, holding the string we need.
    zone = collect where {CallerReference: spec.cluster.vpc_id}, data.HostedZones
    if empty zone
      spec.cluster.zones = private: id: false
    else
      spec.cluster.zones = private: id: zone[0].Id

    return spec
