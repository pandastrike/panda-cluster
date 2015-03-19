# Confirm that the named SSH key exists in your AWS account.
validate_key_name = async (key_name, creds) ->
  AWS.config = set_aws_creds creds
  ec2 = new AWS.EC2()
  describe_key_pairs = lift_object ec2, ec2.describeKeyPairs

  try
    data = yield describe_key_pairs {}
    names = pluck data.KeyPairs, "KeyName"
    unless key_name in names
      return build_error "This AWS account does not have a key pair named \"#{key_name}\"."

    return true # validated

  catch err
    return build_error "Unable to validate SSH key.", err



# Get the ID of the VPC we just created for the cluster.  In the CloudFormation
# template, we specified a VPC that is tagged with the cluster's StackName.
get_cluster_vpc_id = async (options, creds) ->
  AWS.config = set_aws_creds creds
  ec2 = new AWS.EC2()
  describe_vpcs = lift_object ec2, ec2.describeVpcs

  params =
    Filters: [
      Name: "tag:Name"
      Values: [
        options.cluster_name
      ]
    ]

  try
    data = yield describe_vpcs params
    # Dig the VPC ID out of the data object and return it.
    return data.Vpcs[0].VpcId

  catch error
    console.log error
    return build_error "Unable to access AWS EC2.", error

# This function checks to see if *all* spot instances within a spot-request are online
# and ready.  Otherwise it returns false.  Used with polling.
get_spot_status = async (options, creds) ->
  AWS.config = set_aws_creds creds
  ec2 = new AWS.EC2()
  describe_spot = lift_object ec2, ec2.describeSpotInstanceRequests

  params =
    Filters: [
      {
        Name: "network-interface.subnet-id"
        Values: [options.subnet_id]
      }
    ]

  try
    data = yield describe_spot params
    state = pluck data.SpotInstanceRequests, "State"
    is_active = (state) -> state == "active"

    if state.length == 0
      return false # Request has yet to be created.
    else if every( state, is_active)
      # *All* spot i nstances are online and ready.
      return {
        result: build_success "Spot Request Fulfilled.", data
        instances: subset(data.SpotInstanceRequests, "InstanceId", "id")
      }
    else
      return false # Request is pending.

  catch error
    console.log error
    return build_error "Unable to access AWS EC2.", error

# When more expensive on-demand instances are used, they start right away with the CloudFormation stack.
# We just need to query AWS with the stack name tags and pull the IDs of active instances.
get_on_demand_instances = async (options, creds) ->
  AWS.config = set_aws_creds creds
  ec2 = new AWS.EC2()
  describe_instances = lift_object ec2, ec2.describeInstances

  params =
    Filters: [
      {
        Name: "tag:aws:cloudformation:stack-name"
        Values: [
          options.cluster_name  # Only examine instances within the stack we just created.
        ]
      }
      {
        Name: "instance-state-code"
        Values: [
          "16"      # Only examine running instances.
        ]
      }
    ]

  try
    data = yield describe_instances params
    return subset(data.Reservations[0].Instances, "InstanceId", "id")
  catch error
    console.log error
    return build_error "Unable to access AWS EC2.", error

# Return the public and private facing IP address of a single instance.
get_ip_address = async (instance_id, creds) ->
  AWS.config = set_aws_creds creds
  ec2 = new AWS.EC2()
  describe_instances = lift_object ec2, ec2.describeInstances

  params =
    Filters: [
      {
        Name: "instance-id"
        Values: [instance_id]
      }
    ]

  try
    data = yield describe_instances params
    return {
      public_ip: data.Reservations[0].Instances[0].PublicIpAddress
      private_ip: data.Reservations[0].Instances[0].PrivateIpAddress
    }

  catch error
    console.log error
    return build_error "Unable to access AWS EC2.", error
