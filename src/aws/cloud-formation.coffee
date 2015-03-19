#===============================================================================
# Panda-Cluster - Cloud Formation
#===============================================================================
# This file specifies the panda-cluster's access to AWS's CloudFormation API.

{get_discovery_url} = require "../magic-numbers"
{lift_object, build_error, build_success} = require "../helpers"
{build_template} = require "./cloud-formation-template"
{validate_key_name} = require "./ec2"

modules.exports = (AWS) ->

  # Authorize access to the CloudFormation API.
  cf = new AWS.CloudFormation()

  # Create lifted versions of API methods.
  create_stack = lift_object cf, cf.createStack



  #-------------------------
  # Exposed Methods
  #-------------------------
  # Launch the procces that eventually creates a CoreOS cluster using the user's AWS account.
  launch_stack = async (options) ->
    try
      # Build the "params" object that is used directly by AWS.
      params = {}
      params.StackName = options.cluster_name
      params.OnFailure = "DELETE"
      params.TemplateBody = yield build_template options

      # Parameters is a map of key/values custom defined for this stack by the
      # template file.  We will now fill out the map as specified or with defaults.
      params.Parameters = [
          # InstanceType
          "ParameterKey": "InstanceType"
          "ParameterValue": options.instance_type
        , # ClusterSize
          "ParameterKey": "ClusterSize"
          "ParameterValue": options.cluster_size
        , # DiscoveryURL - Grab a randomized URL from etcd's free discovery service.
          "ParameterKey": "DiscoveryURL"
          "ParameterValue": yield get_discovery_url()
        , # KeyPair
          "ParameterKey": "KeyPair"
          "ParameterValue": options.key_name if yield validate_key_name( options.key_name, creds)
      ]

      # Preparations complete.  Access AWS.
      data = yield create_stack params
      return build_success "Cluster formation in progress.", data

    catch error
      throw build_error "Unable to access AWS CloudFormation", error



  # This function checks the specified AWS stack to see if its formation is complete.
  # It returns either true or false, and throws an exception if an AWS error is reported. Used with polling.
  get_formation_status = async (options, creds) ->
    AWS.config = set_aws_creds creds
    cf = new AWS.CloudFormation()
    describe_events = lift_object cf, cf.describeStackEvents

    try
      data = yield describe_events {StackName: options.cluster_name}

      if data.StackEvents[0].ResourceType == "AWS::CloudFormation::Stack" &&
      data.StackEvents[0].ResourceStatus == "CREATE_COMPLETE"
        return build_success "The cluster is confirmed to be online and ready.", data

      else if data.StackEvents[0].ResourceStatus == "CREATE_FAILED" ||
      data.StackEvents[0].ResourceStatus == "DELETE_IN_PROGRESS"
        return build_error "AWS CloudFormation returned unsuccessful status.", data

      else
        return false

    catch err
      return build_error "Unable to access AWS CloudFormation.", err



  # Retrieve the subnet ID of the subnet we just created.  We can use the stack name
  # to query AWS for the physical ID.
  get_cluster_subnet = async (options, creds) ->
    AWS.config = set_aws_creds creds
    cf = new AWS.CloudFormation()
    describe_resources = lift_object cf, cf.describeStackResources

    params =
      StackName: options.cluster_name
      LogicalResourceId: "ClusterSubnet"

    try
      data = yield describe_resources params
      return data.StackResources[0].PhysicalResourceId
    catch error
      build_error "Unable to access AWS CloudFormation.", error
