#===============================================================================
# PandaCluster - Awesome Command-Line Tool and Library to Manage CoreOS Clusters
#===============================================================================

#====================
# Modules
#====================
https = require "https"
{resolve} = require "path"

# In-House Libraries
{parse} = require "c50n"                  # .cson file parsing
{dashed} = require "fairmont"

# Awsome functional style tricks.
{where, pluck, every} = require "underscore"

# When Library
{promise, lift} = require "when"
{liftAll} = require "when/node"
node_lift = (require "when/node").lift
async = (require "when/generator").lift

# ShellJS
{exec, error} = require "shelljs"

# Included modules from PandaCluster
{render_template, simple_render} = require "./templatize"

# Access AWS API
AWS = require "aws-sdk"


#================================
# Helper Functions
#================================
# Create a list of objects, where the new objects are a subset of their original input.  "key" is
# a simple string naming the target objects's *key* (cannot filter based on *value*).
# "new_key" is optional and allows the objects to use a new string for its keys.
subset = (map_list, key, new_key) ->
  result = []
  values = pluck(map_list, key)
  new_key ||= key

  for value in values
    temp = {}
    temp[new_key] = value
    result.push temp

  return result


# Enforces "fully qualified" form of hostnames and domains.  Idompotent.
fully_qualified = (name) ->
  if name[name.length - 1] == "."
    return name
  else
    return name + "."

# This is named somewhat sarcastically.  Enforces "regular" form of hostnames and domains that
# is more useful to navigating.  Idompotnent.
regularly_qualified = (name) ->
  if name[name.length - 1] == "."
    return name.slice(0, name.length - 1)
  else
    return name

# Render underscores and dashes as whitespace.
plain_text = (string) ->
  string
  .replace( /_+/g, " " )
  .replace( /\W+/g, " " )

# Build an error object to let the user know something went worng.
build_error = (message, details) ->
  error = new Error message
  error.details = details    if details?
  return error

# Create a success object that reports data to user.
build_success = (message, data) ->
  return {
    message: message
    status: "success"
    details: data       if data?
  }


# Lift Node's async read/write functions.
{read_file, write_file} = do ->
  {readFile, writeFile} = liftAll(require "fs")

  read_file: async (path) ->
    (yield readFile path, "utf-8").toString()

  write_file: (path, content) ->
    writeFile path, content, "utf-8"

# Create a version of ShellJS's "exec" command with built-in error handling.  In
# PandaCluster, we regularly use "exec" with SSH commands and other longish-running
# processes, so we want to wrap "exec" in a promise and use "yield" statements.
execute = (command, debug) ->
  promise (resolve, reject) ->
    exec command, (code, output) ->
      if debug?
        resolve output

      if code == 0
        resolve build_success "ShellJS successfully executed the specified shell command.", output
      else
        resolve build_error "ShellJS failed to execute shell command."



# Allow "when" to lift AWS module functions, which are non-standard.
lift_object = (object, method) ->
  node_lift method.bind object

# This is a wrap of setTimeout with ES6 technology that forces a non-blocking
# pause in execution for the specified duration (in ms).
pause = (duration) ->
  promise (resolve, reject) ->
    callback = -> resolve()
    setTimeout callback, duration

# Continue calling the async function until truthy value is returned.
# Takes optional maximum iterations before continuing.
poll_until_true = async (func, options, creds, duration, message, max) ->
  try
    # Initialize counter if we have a maximum.
    count = 0  if max?
    while true
      # Poll the function.
      status = yield func options, creds
      if status
        return status         # Complete.
      else
        yield pause duration  # Not complete. Keep going.

      # Iterate the counter
      count++ if max?
      return "WARNING: Max iterations reached.  Continuing Setup Anyway."  if count? > max?

  catch error
    return build_error message, error


# Promise wrapper around Node's https module. Makes GET calls into promises.
https_get = (url) ->
  promise (resolve, reject) ->
    https.get url
    .on "response", (response) ->
      resolve response
    .on "error", (error) ->
      resolve error

# Promise wrapper around response events that read "data" from the response's body.
get_body = (response) ->
  promise (resolve, reject) ->
    data = ""

    response.setEncoding "utf8"
    .on "data", (chunk) ->
      data = data + chunk
    .on "end", ->
      resolve data
    .on "error", (error) ->
      resolve error

# Wrapper for https call to etcd's discovery API.
get_discovery_url = async -> yield get_body( yield https_get( "https://discovery.etcd.io/new"))

enforce_create_cluster_defaults = (options) ->
  options.channel         ||= "stable"
  options.instance_type   ||= "m1.medium"
  options.cluster_size    ||= "3"
  options.virtualization  ||= "pv"
  options.private_domain  ||= "#{options.cluster_name}.cluster"

  options.cluster_size  = String(options.cluster_size)
  options.spot_price    = String(options.spot_price)     if options.spot_price?

  # options.tags = [
  #   {
  #     Key: "Name"
  #     Value: "DavidTest"
  #   }
  #   {
  #     Key: "customer"
  #     Value: "pandastrike"
  #   }
  #   {
  #     Key: "environment"
  #     Value: "test"
  #   }
  #   {
  #     Key: "project"
  #     Value: "huxley"
  #   }
  #   {
  #     Key: "role"
  #     Value: "coreos"
  #   }
  # ]

  return options

# This function starts an input configuration object default and merges it with the input.
default_merge = async (name, unit, default_path) ->
  final = (parse( yield read_file( default_path)))[name]
  unless unit == "default"
    final[key] = unit[key]  for key of unit

  return final

# Render the template of one of many possible service files.  Write to the Launch Directory.
render_service_template = async (config_name, input, root_directory) ->
  template_name = dashed plain_text config_name
  path_to_template = resolve root_directory, "launch/#{template_name}/#{template_name}.template"

  content = yield render_template config_name, input, path_to_template
  path = resolve root_directory, "launch/#{template_name}/#{template_name}.service"
  yield write_file path, content



# Render the template of one of the more rare service files that are included in cluster-formation.
render_formation_service_template = async (config_name, input) ->
  template_name = dashed plain_text config_name
  path_to_template = resolve __dirname, "formation-services/#{template_name}.template"
  path_to_defaults = resolve __dirname, "formation-services/defaults.cson"
  yield render_template config_name, input, path_to_template, path_to_defaults


# Pulls the most recent AWS CloudFormation template from CoreOS.
pull_cloud_template = async ({channel, virtualization}) ->
  # This directory has a handy CSON file of URLs for CoreOS's latest CloudFormation templates.
  template_store = parse( yield read_file( resolve( __dirname, "cloudformation-templates.cson")))
  template_url = template_store[channel][virtualization]

  try
    response = yield https_get template_url
    template_object = JSON.parse (yield get_body response)
    return template_object

  catch error
    return build_error "Unable to access AWS template stores belonging to CoreOS", error



# Add unit to the cloud-config section of the AWS template.
add_unit = async (cloud_config, name, unit) ->
  # The cloud-config file is stored as an array of strings inside the "UserData"
  # object of the AWS template.  We wish to add additional strings to this array.
  # We need to be careful because "cloud-config" files are formatted in YAML,
  # which is sensitive to indentation....

  default_path = resolve __dirname, "formation-services/defaults.cson"
  unit = yield default_merge name, unit, default_path

  # Add to the cloud_config array.
  cloud_config.push "    - name: #{unit.output_filename}\n"
  cloud_config.push "      runtime: #{unit.runtime}\n"   if unit.runtime?
  cloud_config.push "      command: #{unit.command}\n"   if unit.command?
  cloud_config.push "      enable: #{unit.enable}\n"     if unit.enable?
  cloud_config.push "      content: |\n"

  # For "content", we draw from a unit-file maintained in a separate file. Add
  # eight spaces to the begining of each line (4 indentations) and follow each
  # line with an explicit new-line character.
  content = yield render_formation_service_template name, unit
  content = content.split "\n"

  while content.length > 0
    cloud_config.push "        " + content[0] + "\n"
    content.shift()

  return cloud_config



# Build an AWS CloudFormation template by augmenting the official ones released
# by CoreOS.  Return a JSON string.
build_template = async (options, creds) ->
  try
    # Pull official CoreOS template as a JSON object.
    template_object = yield pull_cloud_template options

    #-----------------------------------------------------
    # Establish And Configure Virtual Private Cloud (VPC)
    #-----------------------------------------------------
    # Isolate the "Resources" object within the JSON template object.
    resources = template_object.Resources

    # Add an object specifying a VPC.
    resources["VPC"] =
      Type: "AWS::EC2::VPC"
      Properties:
        CidrBlock: "10.0.0.0/16"
        EnableDnsSupport: true
        EnableDnsHostnames: true
        Tags: [
          {
            Key: "Name"
            Value: options.cluster_name
          }
        ]


    # Add an object specifying a subnet.
    resources["ClusterSubnet"] =
      Type: "AWS::EC2::Subnet"
      Properties:
        AvailabilityZone: "us-west-1c"
        VpcId: { Ref: "VPC" }
        CidrBlock : "10.0.0.0/16"


    # Add an object specifying an Internet Gateway.
    resources["ClusterGateway"] =
      Type: "AWS::EC2::InternetGateway"
      Properties:
        Tags: [
          {
            Key: "Name"
            Value: options.cluster_name
          }]

    # Add an object specifying the attachment of this Internet Gateway.
    resources["AttachClusterGateway"] =
      Type: "AWS::EC2::VPCGatewayAttachment"
      Properties:
        InternetGatewayId: {Ref: "ClusterGateway"}
        VpcId: {Ref: "VPC"}

    # Add an object specifying the creation of a new Route Table.
    resources["ClusterRouteTable"] =
      Type: "AWS::EC2::RouteTable"
      Properties:
        VpcId: {Ref: "VPC"}
        Tags: [
          {
            Key: "Name"
            Value: options.cluster_name
          }]

    # Add an object specifying a Route for public addresses (through the Internet Gateway).
    resources["PublicRoute"] =
      Type: "AWS::EC2::Route"
      DependsOn: "ClusterGateway"
      Properties:
        DestinationCidrBlock: "0.0.0.0/0"
        GatewayId: {Ref: "ClusterGateway"}
        RouteTableId: {Ref: "ClusterRouteTable"}

    # Add an object associating the new Route Table with our VPC.
    resources["AttachRouteTable"] =
      Type: "AWS::EC2::SubnetRouteTableAssociation"
      Properties:
        RouteTableId: {Ref: "ClusterRouteTable"}
        SubnetId: {Ref: "ClusterSubnet"}


    # Replace the objects specifying the SecurityGroups.
    # Start by deleting the current configuration.  We need start over to accomodate the VPC.
    delete resources.CoreOSSecurityGroup
    delete resources.Ingress4001
    delete resources.Ingress7001

    # Expose the following ports...
    resources["ClusterSecurityGroup"] =
      Type: "AWS::EC2::SecurityGroup"
      Properties:
        GroupDescription: "PandaCluster SecurityGroup"
        VpcId: {Ref: "VPC"}
        SecurityGroupIngress: [
          { # SSH Exposed to the public Internet
            IpProtocol: "tcp"
            FromPort: "22"
            ToPort: "22"
            CidrIp: "0.0.0.0/0"
          }
          { # HTTP Exposed to the public Internet
            IpProtocol: "tcp"
            FromPort: "80"
            ToPort: "80"
            CidrIp: "0.0.0.0/0"
          }
          { # HTTPS Exposed to the public Internet
            IpProtocol: "tcp"
            FromPort: "443"
            ToPort: "443"
            CidrIp: "0.0.0.0/0"
          }
          { # Privileged ports exposed only to machines within the cluster.
            IpProtocol: "tcp"
            FromPort: "2000"
            ToPort: "2999"
            CidrIp: "10.0.0.0/8"
          }
          { # Free ports exposed to public Internet.
            IpProtocol: "tcp"
            FromPort: "3000"
            ToPort: "3999"
            CidrIp: "0.0.0.0/0"
          }
          { # Exposed to Internet for etcd. TODO: Lock down so only CoreOS can access.
            IpProtocol: "tcp"
            FromPort: "4001"
            ToPort: "4001"
            CidrIp: "0.0.0.0/0"
          }
          { # Exposed to Internet for clustering. TODO: Lock down so only CoreOS can access.
            IpProtocol: "tcp"
            FromPort: "7001"
            ToPort: "7001"
            CidrIp: "0.0.0.0/0"
          }
        ]


    # Modify the object specifying the cluster's LaunchConfig.  Associate with our new SecurityGroup.
    resources.CoreOSServerLaunchConfig["DependsOn"] = "ClusterGateway"
    resources.CoreOSServerLaunchConfig.Properties.SecurityGroups = [ {Ref: "ClusterSecurityGroup"} ]
    resources.CoreOSServerLaunchConfig.Properties.AssociatePublicIpAddress = "true"
    # Also give it a Spot Price if the user seeks to keep the cost down.
    if options.spot_price?
      resources.CoreOSServerLaunchConfig.Properties.SpotPrice = options.spot_price

    # Modify the object specifying the cluster's auto-scaling group.  Associate with the VPC.
    resources.CoreOSServerAutoScale["DependsOn"] = "ClusterGateway"
    resources.CoreOSServerAutoScale.Properties["VPCZoneIdentifier"] = [{Ref: "ClusterSubnet"}]
    resources.CoreOSServerAutoScale.Properties.AvailabilityZones = ["us-west-1c"]

    # Associate the cluster's auto-scaling group with the user-specified tags.
    if options.tags? && options.tags.length > 0
      resources.CoreOSServerAutoScale.Properties.Tags = []
      for tag in options.tags
        new_tag = tag
        new_tag["PropagateAtLaunch"] = "true"
        resources.CoreOSServerAutoScale.Properties.Tags.push new_tag

    # Place "Resources" back into the JSON template object.
    template_object.Resources = resources

    #----------------------------
    # Cloud-Config Modifications
    #----------------------------
    # Isolate the cloud-config array within the JSON object.
    user_data = template_object.Resources.CoreOSServerLaunchConfig.Properties.UserData
    cloud_config = user_data["Fn::Base64"]["Fn::Join"][1]

    # Add the specified units to the cloud-config section.
    if options.formation_service_templates?
      for x of options.formation_service_templates
        cloud_config = yield add_unit cloud_config, x, options.formation_service_templates[x]

    # Add the specified public keys.  We must be careful with indentation formatting.
    unless !options.public_keys || options.public_keys == []
      cloud_config.push "ssh_authorized_keys: \n"
      for x in options.public_keys
        cloud_config.push "  - #{x}\n"

    # Place this array back into the JSON object.  Construction complete.
    user_data["Fn::Base64"]["Fn::Join"][1] = cloud_config
    template_object.Resources.CoreOSServerLaunchConfig.Properties.UserData = user_data

    # Return the JSON string.
    return JSON.stringify template_object, null, "\t"

  catch error
    console.log error
    return build_error "Unable to build CloudFormation template.", error


# Configure the AWS object for account access.
set_aws_creds = (creds) ->
  try
    return {
      accessKeyId: creds.id
      secretAccessKey: creds.key
      region: creds.region
      sslEnabled: true
    }
  catch error
    console.log "AWS Credential Issue.", error
    return build_error "Unable to configure AWS.config object", error


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



# Launch the procces that eventually creates a CoreOS cluster using the user's AWS account.
launch_stack = async (options, creds) ->
  try
    # Build the "params" object that is used directly by AWS.
    params = {}
    params.StackName = options.cluster_name
    params.OnFailure = "DELETE"
    params.TemplateBody = yield build_template options, creds

    #---------------------------------------------------------------------------
    # Parameters is a map of key/values custom defined for this stack by the
    # template file.  We will now fill out the map as specified or with defaults.
    #---------------------------------------------------------------------------
    params.Parameters = [

      { # InstanceType
        "ParameterKey": "InstanceType"
        "ParameterValue": options.instance_type
      }

      { # ClusterSize
        "ParameterKey": "ClusterSize"
        "ParameterValue": options.cluster_size
      }

      { # DiscoveryURL - Grab a randomized URL from etcd's free discovery service.
        "ParameterKey": "DiscoveryURL"
        "ParameterValue": yield get_discovery_url()
      }

      { # KeyPair
        "ParameterKey": "KeyPair"
        "ParameterValue": options.key_name if yield validate_key_name( options.key_name, creds)
      }
    ]

    # Preparations complete.  Access AWS.
    AWS.config = set_aws_creds creds
    cf = new AWS.CloudFormation()
    create_stack = lift_object cf, cf.createStack

    data = yield create_stack params
    return build_success "Cluster formation in progress.", data

  catch error
    console.log error
    return build_error "Unable to access AWS CloudFormation", error


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



#-------------------------
# Cluster Customization
#-------------------------

#----------------------------
# General DNS Fucntions
#----------------------------
# Given a URL of many possible formats, return the root domain.
# https://awesome.example.com/test/42#?=What+is+the+answer  =>  example.com.
get_hosted_zone_name = (url) ->
  try
    # Find and remove protocol (http, ftp, etc.), if present, and get domain

    if url.indexOf("://") != -1
      domain = url.split('/')[2]
    else
      domain = url.split('/')[0]

    # Find and remove port number
    domain = domain.split(':')[0]

    # Now grab the root domain, the top-level-domain, plus what's to the left of it.
    # Be careful of tld's that are followed by a period.
    foo = domain.split "."
    if foo[foo.length - 1] == ""
      domain = "#{foo[foo.length - 3]}.#{foo[foo.length - 2]}"
    else
      domain = "#{foo[foo.length - 2]}.#{foo[foo.length - 1]}"

    # And finally, make the sure the root_domain ends with a "."
    domain = domain + "."
    return domain

  catch error
    return build_error "There was an issue parsing the requested hostname.", error


# Get the AWS HostedZoneID for the provided (fully specified) public domain.
get_public_zone_id = async (domain, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_zones = lift_object r53, r53.listHostedZones

    data = yield list_zones {}

    # Dig the ID out of an array, holding an object, holding the string we need.
    return where( data.HostedZones, {Name:domain})[0].Id


  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error



# Get the IP address currently associated with the hostname.
get_dns_record = async (hostname, zone_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_records = lift_object r53, r53.listResourceRecordSets

    data = yield list_records {HostedZoneId: zone_id}

    # We need to conduct a little parsing to extract the IP address of the record set.
    record = where data.ResourceRecordSets, {Name:hostname}

    if record.length == 0
      return {
        current_ip_address: null
        current_type: null
      }

    return {
      current_ip_address: record[0].ResourceRecords[0].Value
      current_type: record[0].Type
    }

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error



# Access Route 53 and alter an existing Route 53 record to a new IP address.
change_dns_record = async (options, creds) ->
  try
    # The params object contains "Changes", an array of actions to take on the DNS
    # records.  Here we delete the old record and add the new IP address.

    # TODO: When we establish an Elastic Load Balancer solution, we
    # will need to the "AliasTarget" sub-object here.
    params =
      HostedZoneId: options.zone_id
      ChangeBatch:
        Changes: [
          {
            Action: "DELETE",
            ResourceRecordSet:
              Name: options.hostname,
              Type: options.current_type,
              TTL: 60,
              ResourceRecords: [
                {
                  Value: options.current_ip_address
                }
              ]
          }
          {
            Action: "CREATE",
            ResourceRecordSet:
              Name: options.hostname,
              Type: options.type,
              TTL: 60,
              ResourceRecords: [
                {
                  Value: options.ip_address
                }
              ]
          }
        ]

    # We are ready to access AWS.
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    change_record = lift_object r53, r53.changeResourceRecordSets

    data = yield change_record params
    return {
      result: build_success "The hostname \"#{options.hostname}\" has been assigned to #{options.ip_address}.", data
      change_id: data.ChangeInfo.Id
    }

  catch error
    console.log error
    return build_error "Unable to assign the IP address to the designated hostname.", error


add_dns_record = async (options, creds) ->
  try
    # The params object contains "Changes", an array of actions to take on the DNS
    # records.  Here we delete the old record and add the new IP address.

    params =
      HostedZoneId: options.zone_id
      ChangeBatch:
        Changes: [
          {
            Action: "CREATE",
            ResourceRecordSet:
              Name: options.hostname,
              Type: options.type,
              TTL: 60,
              ResourceRecords: [
                {
                  Value: options.ip_address
                }
              ]
          }
        ]

    # We are ready to access AWS.
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    change_record = lift_object r53, r53.changeResourceRecordSets

    data = yield change_record params
    return {
      result: build_success "The hostname \"#{options.hostname}\" has been created and assigned to #{options.ip_address}.", data
      change_id: data.ChangeInfo.Id
    }

  catch error
    console.log error
    return build_error "Unable to assign the IP address to the designated hostname.", error


# Delete the specified DNS record.
delete_dns_record = async (options, creds) ->
  try
    params =
      HostedZoneId: options.zone_id
      ChangeBatch:
        Changes: [
          {
            Action: "DELETE",
            ResourceRecordSet:
              Name: options.hostname,
              Type: options.type,
              TTL: 60,
              ResourceRecords: options.value
          }
        ]

    # We are ready to access AWS.
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    change_record = lift_object r53, r53.changeResourceRecordSets

    data = yield change_record params
    return {
      result: build_success "The hostname \"#{options.hostname}\" has been deleted.", data
      change_id: data.ChangeInfo.Id
    }

  catch error
    console.log error
    return build_error "Unable to delete the designated hostname.", error



# This function checks the specified DNS record to see if it's "INSYC", done updating.
# It returns either true or false, and throws an exception if an AWS error is reported.
get_record_change_status = async (change_id, creds) ->
  AWS.config = set_aws_creds creds
  r53 = new AWS.Route53()
  get_change = lift_object r53, r53.getChange

  try
    data = yield get_change {Id: change_id}

    if data.ChangeInfo.Status == "INSYNC"
      return build_success "The DNS record is fully synchronized.", data
    else
      return false

  catch err
    console.log error
    return build_error "Unable to access AWS Route53.", err


# Given a hostname for the cluster, add a new or alter an existing DNS record that routes
# to the cluster's IP address.
set_hostname = async (options, creds) ->
  try
    # We need to determine if the requested hostname is currently assigned in a DNS record.
    {current_ip_address, current_type} = yield get_dns_record( options.hostname, options.public_zone_id, creds)

    if current_ip_address?
      console.log "Changing Current Record."
      # There is already a record.  Change it.
      params =
        hostname: options.hostname
        zone_id: options.public_zone_id
        current_ip_address: current_ip_address
        current_type: current_type
        type: "A"
        ip_address: options.instances[0].public_ip

      return yield change_dns_record params, creds
    else
      console.log "Adding New Record."
      # No existing record is associated with this hostname.  Create one.
      params =
        hostname: options.hostname
        zone_id: options.public_zone_id
        type: "A"
        ip_address: options.instances[0].public_ip

      return yield add_dns_record params, creds

  catch error
    console.log error
    return build_error "Unable to set the hostname to the cluster's IP address.", error



# Using Private DNS from Route 53, we need to give the cluster a private domain
# so services may be referenced with human-friendly names.
create_private_domain = async (options, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    create_zone = lift_object r53, r53.createHostedZone

    params =
      CallerReference: options.vpc_id
      Name: options.private_domain
      VPC:
        VPCId: options.vpc_id
        VPCRegion: creds.region

    data = yield create_zone params
    return {
      result: build_success "The Cluster's private DNS has been established.", data
      change_id: data.ChangeInfo.Id
      zone_id: data.HostedZone.Id
    }

  catch error
    console.log error
    return build_error "Unable to establish the cluster's private DNS.", error


delete_domain = async (zone_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    delete_zone = lift_object r53, r53.deleteHostedZone

    data = yield delete_zone {Id: zone_id}
    return build_success "The specified domain has been successfully deleted.", data

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53", error


# This function checks the specified Hosted Zone to see if its "INSYC", done updating.
# It returns either true or false, and throws an exception if an AWS error is reported.
get_hosted_zone_status = async (change_id, creds) ->
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    get_hosted_zone = lift_object r53, r53.getHostedZone

    try
      data = yield get_hosted_zone {Id: change_id}

      if data.ChangeInfo.Status == "INSYNC"
        return build_success "The private DNS is fully online.", data
      else
        return false

    catch err
      console.log error
      return build_error "Unable to access AWS Route53.", err

# This function will return the ID of the cluster's private Hosted Zone, provided the VPC ID.
get_private_zone_id = async (vpc_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_zones = lift_object r53, r53.listHostedZones

    data = yield list_zones {}

    # Dig the ID out of an array, holding an object, holding the string we need.
    return where( data.HostedZones, {CallerReference: vpc_id})[0].Id

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error


# This function queries AWS for all the DNS records belonging to a particular Hosted Zone.
get_all_records = async (zone_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    get_records = lift_object r53, r53.listResourceRecordSets

    data = yield get_records {HostedZoneId: zone_id}

    records = []
    for x in data.ResourceRecordSets
      if x.Type != "SOA" && x.Type != "NS"
        records.push {
          hostname: x.Name
          type: x.Type
          value: x.ResourceRecords
        }

    return records

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error




# This function takes a HostedZone's ID and deletes it.
delete_hosted_zone = async (zone_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_zones = lift_object r53, r53.listHostedZones

    data = yield list_zones {}

    # Dig the ID out of an array, holding an object, holding the string we need.
    return where( data.HostedZones, {CallerReference: vpc_id})[0].Id

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error

#---------------------------------
# Launch Repository + Kick Server
#--------------------------------

# Prepare the cluster to be self-sufficient by installing directory called "launch".
# "launch" acts as a repository where each service will have its own sub-directory
# containing a Dockerfile, *.service file, and anything else it needs.  Because we
# don't know which machine will host the service, copies of the launch directory need
# to be on every machine.
prepare_launch_directory = async (options) ->
  output = []
  try
    for address in pluck( options.instances, "public_ip")
      # Dump the repo's launch directory on the cluster.
      command =
        "ssh -A -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile=/dev/null\" " +
        "core@#{address} << EOF \n " +
        "mkdir launch \n" +
        "EOF"


      output.push yield execute command

    return build_success "The Launch Repositories are ready.", output
  catch error
    return build_error "Unable to install the Launch Repository.", error


# Prepare the cluster to be self-sufficient by launching the Kick API server on the "main"
# cluster machine.  This is short for "sidekick service"; a primative, meta API server that allows
# the cluster to act with some autonomy when prompted by a remote agent.  The Kick server is Dockerized.
prepare_kick = async (options, creds) ->
  output = {}
  try
    # Add the kick server to the cluster's private DNS records.
    params =
      hostname: "kick.#{options.private_domain}"
      zone_id: options.private_zone_id
      type: "A"
      ip_address: options.instances[0].private_ip[0]

    console.log "Adding Kick Server to DNS Record"
    {result, change_id} = yield add_dns_record( params, creds)
    output.register_kick = result

    console.log "Building Kick Container...  This will take a moment."
    # Pull the Kick's Docker container from the public repo.
    command =
      #"ssh -A -o \"StrictHostKeyChecking no\" -o \"LogLevel=quiet\" -o \"UserKnownHostsFile=/dev/null\" " +
      "ssh -A -o \"StrictHostKeyChecking no\"  -o \"UserKnownHostsFile=/dev/null\" " +
      "core@#{options.instances[0].public_ip} << EOF\n" +
      "docker pull pandastrike/pc_kick \n" +
      "EOF"

    output.build_kick = yield execute command

    # Activate the kick server and pass in the user's AWS credentials.  We need to get the
    # credentials *into* the kick server at runtime and obey CSON formatting rules.  That's
    # why we rely on a runtime `sed` command to make it happen while avoiding placing the user
    # credentials in multiple places.  They exist only in the running container and are *NOT*
    # stored in the image.
    public_zone_id = options.public_zone_id.split("/")[2]
    private_zone_id = options.private_zone_id.split("/")[2]

    command =
      "ssh -A -o \"StrictHostKeyChecking no\" -o \"LogLevel=quiet\" -o \"UserKnownHostsFile=/dev/null\" " +
      "core@#{options.instances[0].public_ip} << EOF\n" +
      "docker run -d -p 2000:80 --name kick pandastrike/pc_kick /bin/bash -c " +
      "\"cd panda-cluster-kick && " +

      "sed \"s/aws_id_goes_here/#{creds.id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/aws_key_goes_here/#{creds.key}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/aws_region_goes_here/#{creds.region}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/public_zone_id_goes_here/#{public_zone_id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/public_zone_name_goes_here/#{options.public_domain}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/private_zone_id_goes_here/#{private_zone_id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/private_zone_name_goes_here/#{options.private_domain}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "coffee --nodejs --harmony kick.coffee\" \n" +
      "EOF"

    output.run_kick = yield execute command
    return {
      result: build_success "The Kick Server is online.", output
      change_id: change_id
    }

  catch error
    return build_error "Unable to install the Kick Server.", error


# Prepare the cluster to be self-sufficient by launching the Hook server on the "main"
# cluster machine.  This is short for "git webhook"; a server that launches arbitary
# scripts based on user interactions via git, which acts over SSH.
prepare_hook = async (options, creds) ->
  output = {}
  try
    # Add the kick server to the cluster's private DNS records.
    params =
      hostname: "hook.#{options.private_domain}"
      zone_id: options.private_zone_id
      type: "A"
      ip_address: options.instances[0].private_ip[0]

    console.log "Adding Hook Server to DNS Record"
    {result, change_id} = yield add_dns_record( params, creds)
    output.register_kick = result


    console.log "Building Hook Container...  This will take a moment."
    # Pull the Hook Server's Docker container from the public repo.
    command =
      #"ssh -A -o \"StrictHostKeyChecking no\" -o \"LogLevel=quiet\" -o \"UserKnownHostsFile=/dev/null\" " +
      "ssh -A -o \"StrictHostKeyChecking no\"  -o \"UserKnownHostsFile=/dev/null\" " +
      "core@#{options.instances[0].public_ip} << EOF\n" +
      "docker pull pandastrike/pc_hook \n" +
      "EOF"

    output.build_hook = yield execute command

    #----------------------------
    # Activate the hook server.
    #----------------------------
    command =
      "ssh -A -o \"StrictHostKeyChecking no\" -o \"LogLevel=quiet\" -o \"UserKnownHostsFile=/dev/null\" " +
      "core@#{options.instances[0].public_ip} << EOF\n" +
      "docker run -d -p 3000:22 -p 2001:80 --name hook pandastrike/pc_hook /bin/bash -c \""

    # Pass in public keys so users may have access.
    for key in options.public_keys
      command = command + " echo \'#{key}\' >> root/.ssh/authorized_keys && "

    # Have the server generate host keys, then activate the SSH server in non-
    # detached mode, which keeps the container online.  We also need to use
    # the setting "UsePAM no".  Otherwise, there is some bug in Docker that
    # causes a connection failure with PAM in place.
    command = command +
      "ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N ''      && " +
      "ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N ''      && " +
      "ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N ''    && " +
      "ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N ''  && " +
      "mkdir /root/repos && " +
      "mkdir /root/passive && " +
      "/usr/sbin/sshd -e -o 'UsePAM no' && " +
      "git daemon --port=80 --base-path=/root --export-all \"\n" +
      "EOF"

    output.run_hook = yield execute command
    return {
      result: build_success "The Hook Server is online.", output
      change_id: change_id
    }

  catch error
    console.log error
    return build_error


# After cluster formation is complete, launch a variety of services
# into the cluster from a library of established unit-files and AWS commands.
customize_cluster = async (options, creds) ->
  # Gather success data as we go.
  data = {}
  dns_changes = {}
  try
    #---------------
    # Hostname
    #---------------
    # Set the specified hostname to the cluster's IP address.
    options.public_domain = fully_qualified options.public_domain
    options.public_zone_id = yield get_public_zone_id( options.public_domain, creds)
    options.hostname = "#{options.cluster_name}.#{options.public_domain}"

    console.log "Registering Cluster in DNS"
    {result, change_id} = yield set_hostname options, creds
    data.set_hostname = result
    dns_changes.hostname = change_id

    #---------------
    # Private DNS
    #---------------
    options.private_domain = fully_qualified options.private_domain

    # Establish a private DNS service available only on the cluster.
    {result, change_id, zone_id} = yield create_private_domain options, creds
    console.log "Private DNS launched: #{options.private_domain} #{change_id} #{zone_id}"
    data.launch_private_domain = result
    options.private_zone_id = zone_id
    data.detect_private_dns_formation = yield poll_until_true get_hosted_zone_status,
      change_id, creds, 5000, "Unable to detect Private DNS formation."
    console.log "Private DNS fully online."

    #---------------------------------------------------
    # Launch Dir + Kick + Hook
    #---------------------------------------------------
    data.prepare_launch_directory = yield prepare_launch_directory options
    console.log "Launch Directory Created."

    result = yield prepare_kick options, creds
    data.prepare_kick = result.result
    dns_changes.kick = result.change_id
    console.log "Kick Server Online."

    result = yield prepare_hook options, creds
    data.prepare_hook = result.result
    dns_changes.hook = result.change_id
    console.log "Hook Server Online."

    #-----------------------------
    # Confirm DNS Changes
    #-----------------------------
    # We poll here to be more efficient.  Amazon should be done updating its DNS records
    # by the time we build all the built-in Docker stuff.  We shave two minutes off
    # our startup time, and just play it safe by double-checking here.
    data.detect_hostname = yield poll_until_true get_record_change_status, dns_changes.hostname,
     creds, 5000, "Unable to detect DNS record change."
    console.log "Cluster Hostname Set"

    data.detect_kick = yield poll_until_true get_record_change_status, dns_changes.kick,
     creds, 5000, "Unable to detect Kick registration.", 25
    console.log "Kick Hostname Set"

    data.detect_kick = yield poll_until_true get_record_change_status, dns_changes.hook,
     creds, 5000, "Unable to detect Kick registration.", 25
    console.log "Hook Hostname Set"


    return build_success "Cluster customizations are complete.", data
  catch error
    console.log error
    return build_error "Unable to properly configure cluster.", error



#---------------------------
# Delete Cluster Functions
#---------------------------

# Delete the private domain associated with the specified cluster.
delete_private_domain = async (options, creds) ->
  try
    # Determine the Hosted Zone ID of the cluster's private domain.
    options.private_zone_id = yield get_private_zone_id options.vpc_id, creds

    # Pull the list of DNS records within this Hosted Zone.
    zone_records = yield get_all_records options.private_zone_id, creds
    return if zone_records.length == 0

    # Delete these records
    for x in zone_records
      params =
        zone_id: options.private_zone_id
        hostname: x.hostname
        type: x.type
        value: x.value
      yield delete_dns_record params, creds

    # Finally, we may delete the private domain.
    data = yield delete_domain options.private_zone_id, creds
    return build_success "The specified domain has been successfully deleted.", data

  catch error
    console.log error
    return build_error "Failed to delete private domain.", error


# Delete the specified CoreOS cluster by deleting its CloudFormation Stack.
delete_stack = async (options, creds) ->
  try
    AWS.config = set_aws_creds creds
    cf = new AWS.CloudFormation()
    deleteStack = lift_object cf, cf.deleteStack

    data = yield deleteStack {StackName: options.cluster_name}
    return build_success "The cluster has been deleted.", data

  catch err
    throw build_error "Unable to access AWS Cloudformation.", err





#===============================
# PandaCluster Definition
#===============================
module.exports =

  #===================
  # Cluster Functions
  #===================

  # This method creates and starts a CoreOS cluster.
  create_cluster: async (options) ->
    credentials = options.aws
    credentials.region = options.region || credentials.region  # allows temporary override of default region.

    # Enforce defaults and formatting.
    options = enforce_create_cluster_defaults options

    try
      # Make calls to Amazon's API. Gather data as we go.
      data = {}
      data.launch_stack = yield launch_stack(options, credentials)
      console.log "Stack Launched.  Formation In-Progress."

      # Monitor the CloudFormation stack until it is fully created.
      data.detect_formation = yield poll_until_true get_formation_status, options,
       credentials, 5000, "Unable to detect cluster formation."
      console.log "Stack Formation Complete."

      # Now that CloudFormation is complete, identify the VPC and subnet that were created.
      options.vpc_id = yield get_cluster_vpc_id options, credentials
      options.subnet_id = yield get_cluster_subnet options, credentials

      # If we're using spot instances, we'll need to wait and detect when our Spot Request has been fulfilled.
      if options.spot_price?
        console.log "Waiting for Spot Instance Fulfillment."
        # Spot Instances - wait for our Spot Request to be fulfilled.
        {result, instances} = yield poll_until_true get_spot_status, options,
         credentials, 5000, "Unable to detect Spot Instance fulfillment."

        data.detect_spot_fulfillment = result
        options.instances = instances
        console.log "Spot Request Fulfilled. Instance Online."
      else
        # On-Demand Instances - already active from CloudFormation.
        options.instances = yield get_on_demand_instances options, credentials
        console.log "On-Demand Instance Online."


      # Get the IP addresses of our instances.
      console.log "Retrieving Primary Public and Private IP Addresses."
      for i in [0..options.instances.length - 1]
        {id} = options.instances[i]
        {public_ip, private_ip} = yield get_ip_address(id, credentials)
        options.instances[i] =
          id: id
          public_ip: public_ip
          private_ip: [private_ip]
        console.log "Instance #{id}: #{public_ip} #{private_ip}"

      # Continue setting up the cluster.
      data.customize_cluster = yield customize_cluster( options, credentials)

      console.log "Done. \n"
      #console.log  JSON.stringify data, null, '\t'
      return build_success "The requested cluster is online, configured, and ready.",
        data


    catch error
      console.log JSON.stringify error, null, '\t'
      return build_error "Apologies. The requested cluster cannot be created.", error


  # This method stops and deletes a CoreOS cluster.
  delete_cluster: async (options) ->
    credentials = options.aws
    credentials.region = options.region || credentials.region

    try
      # Make calls to Amazon's API. Gather data as we go.
      data = {}

      # Before we delete the stack, we must identify other resources associated with the cluster.
      # We can use the the ID of the VPC where the cluster resides.  Identify it.
      options.vpc_id = yield get_cluster_vpc_id options, credentials

      # Now delete the associated resources.
      data.delete_private_domain = yield delete_private_domain( options, credentials)

      # Delete the CloudFormation Stack running our cluster.
      data.delete_stack = yield delete_stack( options, credentials)

      console.log "Done. \n"
      return build_success "The targeted cluster has been destroyed.  All related resources have been released.",
      data

    catch error
      return build_error "Apologies. The targeted cluster has not been destroyed.", error

   get_cluster_status: async (options) ->
       credentials = options.aws
       credentials.region = options.region || credentials.region
       yield get_formation_status options, credentials
