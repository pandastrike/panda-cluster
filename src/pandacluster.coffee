#===============================================================================
# PandaCluster - Awesome Command-Line Tool and Library to Manage CoreOS Clusters
#===============================================================================

#====================
# Modules
#====================
https = require "https"
{resolve} = require "path"

# In-House Libraries
{read, write} = require "fairmont"        # Easy file read/write
{parse} = require "c50n"                  # .cson file parsing

{where} = require "underscore"

# When Library
{promise, lift} = require "when"
{liftAll} = require "when/node"
node_lift = (require "when/node").lift
async = (require "when/generator").lift

# ShellJS
{exec, error} = require "shelljs"

# Access AWS API
AWS = require "aws-sdk"


#================================
# Helper Functions
#================================
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

# Create a version of ShellJS's "exec" command with built-in error handling.  In
# PandaCluster, we regularly use "exec" with SSH commands and other longish-running
# processes, so we want to wrap "exec" in a promise and use "yield" statements.
execute = (command) ->
  promise (resolve, reject) ->
    exec command, (code, output) ->
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

poll_until_true = async (func, options, creds, duration, message) ->
  try

    while true
      status = yield func options, creds
      if status
        return status         # Complete.
      else
        yield pause duration  # Not complete. Keep going.

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


# Pulls the most recent AWS CloudFormation template from CoreOS.
pull_cloud_template = async ({channel, virtualization}) ->
  # Set reasonable defaults for these preferences.
  channel ||= "stable"
  virtualization ||= "pv"

  # This directory has a handy CSON file of URLs for CoreOS's latest CloudFormation templates.
  template_store = parse( read( resolve( __dirname, "templates.cson")))
  template_url = template_store[channel][virtualization]

  try
    response = yield https_get template_url
    template_object = JSON.parse (yield get_body response)
    return template_object

  catch error
    return build_error "Unable to access AWS template stores belonging to CoreOS", error



# Add unit to the cloud-config section of the AWS template.
add_unit = (cloud_config, unit) ->
  # The cloud-config file is stored as an array of strings inside the "UserData"
  # object of the AWS template.  We wish to add additional strings to this array.
  # We need to be careful because "cloud-config" files are formatted in YAML,
  # which is sensitive to indentation....

  # Add to the cloud_config array.
  cloud_config.push "    - name: #{unit.name}\n"
  cloud_config.push "      runtime: #{unit.runtime}\n"   if unit.runtime?
  cloud_config.push "      command: #{unit.command}\n"   if unit.command?
  cloud_config.push "      enable: #{unit.enable}\n"     if unit.enable?
  cloud_config.push "      content: |\n"

  # For "content", we draw from a unit-file maintained in a separate file. Add
  # eight spaces to the begining of each line (4 indentations) and follow each
  # line with an explicit new-line character.
  content = read( resolve( __dirname, "formation-services/#{unit.name}"))
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
            Key: "VPC-Name"
            Value: options.stack_name
          }
        ]


    # Expose addtional ports to machines within the cluster.  By default, only
    # port 22 is exposed to the public Internet.  4001 and 7001 are exposed to CoreOS's
    # (as in the company) servers to make etcd and inter-machine commication work properly.
    resources["InternalSecurityGroup"] =
      Type: "AWS::EC2::SecurityGroup"
      Properties:
        GroupDescription: "Exposes a set of ports to other machines in the cluster ONLY."
        VpcId: {Ref: "VPC"}
        SecurityGroupIngress: [{
          IpProtocol: "tcp"
          FromPort: "2000"
          ToPort: "2999"
          CidrIp: "10.0.0.0/8"  # These are all of the VPC's internal IP addresses.
        }]

    # Place "Resources" back into the JSON template object.
    template_object.Resources = resources



    #----------------------------
    # Cloud-Config Modifications
    #----------------------------
    # Isolate the cloud-config array within the JSON object.
    user_data = template_object.Resources.CoreOSServerLaunchConfig.Properties.UserData
    cloud_config = user_data["Fn::Base64"]["Fn::Join"][1]

    # Add the specified units to the cloud-config section.
    unless options.formation_units == []
      for x in options.formation_units
        cloud_config = add_unit cloud_config, x

    # Add the specified public keys.  We must be careful with indentation formatting.
    unless options.public_keys == []
      cloud_config.push "ssh_authorized_keys: \n"
      for x in options.public_keys
        cloud_config.push "  - #{x}\n"

    # Place this array back into the JSON object.  Construction complete.
    user_data["Fn::Base64"]["Fn::Join"][1] = cloud_config
    template_object.Resources.CoreOSServerLaunchConfig.Properties.UserData = user_data

    # Return the JSON string.
    return JSON.stringify template_object, null, "\t"

  catch error
    return build_error "Unable to build CloudFormation template.", error


# Configure the AWS object for account access.
set_aws_creds = (creds) ->
  return {
    accessKeyId: creds.id
    secretAccessKey: creds.key
    region: creds.region
    sslEnabled: true
  }


# Confirm that the named SSH key exists in your AWS account.
validate_key_pair = async (key_pair, creds) ->
  AWS.config = set_aws_creds creds
  ec2 = new AWS.EC2()
  describe_key_pairs = lift_object ec2, ec2.describeKeyPairs

  try
    data = yield describe_key_pairs {}
    names = []
    names.push key.KeyName    for key in data.KeyPairs

    unless key_pair in names
      return build_error "This AWS account does not have a key pair named \"#{key_pair}\"."

    return true # validated

  catch err
    return build_error "Unable to validate SSH key.", err



# Launch the procces that eventually creates a CoreOS cluster using the user's AWS account.
launch_stack = async (options, creds) ->
  try
    # Build the "params" object that is used directly by AWS.
    params = {}
    params.StackName = options.stack_name
    params.OnFailure = "DELETE"
    params.TemplateBody = yield build_template options, creds

    #---------------------------------------------------------------------------
    # Parameters is a map of key/values custom defined for this stack by the
    # template file.  We will now fill out the map as specified or with defaults.
    #---------------------------------------------------------------------------
    params.Parameters = [

      { # InstanceType
        "ParameterKey": "InstanceType"
        "ParameterValue": options.instance_type || "m3.medium"
      }

      { # ClusterSize
        "ParameterKey": "ClusterSize"
        "ParameterValue": options.cluster_size || "3"
      }

      { # DiscoveryURL - Grab a randomized URL from etcd's free discovery service.
        "ParameterKey": "DiscoveryURL"
        "ParameterValue": yield get_discovery_url()
      }

      { # KeyPair
        "ParameterKey": "KeyPair"
        "ParameterValue": options.key_pair if yield validate_key_pair( options.key_pair, creds)
      }

      # AdvertisedIPAddress - uses default "private",    TODO: Add this option
      # AllowSSHFrom        - uses default "everywhere", TODO: Add this option
    ]

    # Preparations complete.  Access AWS.
    AWS.config = set_aws_creds creds
    cf = new AWS.CloudFormation()
    create_stack = lift_object cf, cf.createStack

    data = yield create_stack params
    return build_success "Cluster formation in progress.", data

  catch err
    return build_error "Unable to access AWS CloudFormation", err


# This function checks the specified AWS stack to see if its formation is complete.
# It returns either true or false, and throws an exception if an AWS error is reported.
get_formation_status = async (options, creds) ->
  AWS.config = set_aws_creds creds
  cf = new AWS.CloudFormation()
  describe_events = lift_object cf, cf.describeStackEvents

  try
    data = yield describe_events {StackName: options.stack_name}

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



#-------------------------
# Cluster Customization
#-------------------------

#----------------------------
# General DNS Fucntions
#----------------------------
# Return the public facing IP address of a single machine from the cluster we just
# created.
get_cluster_ip_address = async (options, creds) ->
    AWS.config = set_aws_creds creds
    ec2 = new AWS.EC2()
    describe_instances = lift_object ec2, ec2.describeInstances

    params =
      Filters: [
        {
          Name: "tag:aws:cloudformation:stack-name"
          Values: [
            options.stack_name  # Only examine instances within the stack we just created.
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
      return {
        ip_address: data.Reservations[0].Instances[0].PublicIpAddress
        private_ip_address: data.Reservations[0].Instances[0].PrivateIpAddress
      }

    catch error
      return build_error "Unable to access AWS EC2.", error


# Given a URL of many possible formats, return the root domain.
# https://awesome.example.com/test/42#?=What+is+the+answer  =>  example.com.
get_root_domain = (url) ->
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


# Get the AWS HostedZoneID for the specified domain.
get_hosted_zone_id = async (hostname, creds) ->
  try
    root_domain = get_root_domain hostname
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_zones = lift_object r53, r53.listHostedZones

    data = yield list_zones {}

    # Dig the ID out of an array, holding an object, holding the string we need.
    return where( data.HostedZones, {Name:root_domain})[0].Id

  catch error
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
      return null
    else
      return {
        current_ip_address: record[0].ResourceRecords[0].Value
        current_type: record[0].Type
      }

  catch error
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
      result: build_success "The domain \"#{options.hostname}\" has been assigned to #{options.ip_address}.", data
      change_id: data.ChangeInfo.Id
    }

  catch error
    return build_error "Unable to assign the IP address to the designated hostname.", error


add_dns_record = async (options, creds) ->
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
      result: build_success "The domain \"#{options.hostname}\" has been created and assigned to #{options.ip_address}.", data
      change_id: data.ChangeInfo.Id
    }

  catch error
    return build_error "Unable to assign the IP address to the designated hostname.", error


# This function checks the specified DNS record to see if its "INSYC", done updating.
# It returns either true or false, and throws an exception if an AWS error is reported.
get_dns_change_status = async (change_id, creds) ->
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
    return build_error "Unable to access AWS Route53.", err


# Given a hostname for the cluster, add a new or alter an existing DNS record that routes
# to the cluster's IP address.
set_hostname = async (options, creds) ->
  try
    # We need to determine if the requested hostname is currently assigned in a DNS record.
    zone_id = yield get_hosted_zone_id( options.hostname, creds)
    {current_ip_address, current_type} = yield get_dns_record( options.hostname, zone_id, creds)

    if current_ip_address?
      # There is already a record.  Change it.
      params =
        hostname: options.hostname
        zone_id: zone_id
        current_ip_address: current_ip_address
        current_type: current_type
        type: "A"
        ip_address: options.ip_address

      return yield change_dns_record params, creds
    else
      # No existing record is associated with this hostname.  Create one.
      params =
        hostname: options.hostname
        zone_id: zone_id
        type: "A"
        ip_address: options.ip_address

      return yield add_dsn_record params, creds

  catch error
    return build_error "Unable to set the hostname to the cluster's IP address.", error





#------------------------
# Private DNS Functions
#------------------------

# Get the ID of the VPC we just created for the cluster.  In the CloudFormation
# template, we specified a VPC that is tagged with the cluster's StackName.
get_cluster_vpc_id = async (options, creds) ->
  AWS.config = set_aws_creds creds
  ec2 = new AWS.EC2()
  describe_vpcs = lift_object ec2, ec2.describeVpcs

  params =
    Filters: [
      Name: "tag:VPC-Name"
      Values: [
        options.stack_name
      ]
    ]

  try
    data = yield describe_vpcs params
    # Dig the VPC ID out of the data object and return it.
    return data.Vpcs[0].VpcId

  catch error
    return build_error "Unable to access AWS EC2.", error



# Using Private DNS from Route 53, we need to give the cluster a private DNS
# so services may be referenced with human-friendly names.
launch_private_dns = async (options, creds) ->
  try
    vpc_id = yield get_cluster_vpc_id options, creds
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    create_zone = lift_object r53, r53.createHostedZone

    params =
      CallerReference: "caller_rference_#{options.dns}_#{new Date().getTime()}"
      Name: options.dns
      VPC:
        VPCId: vpc_id
        VPCRegion: creds.region

    data = yield create_zone params
    return {
      result: build_success "The Cluster's private DNS has been established.", data
      change_id: data.ChangeInfo.Id
      zone_id: data.HostedZone.Id
    }

  catch error
    return build_error "Unable to establish the cluster's private DNS.", error


# This function checks the specified Hosted Zone to see if its "INSYC", done updating.
# It returns either true or false, and throws an exception if an AWS error is reported.
get_private_dns_status = async (change_id, creds) ->
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
      return build_error "Unable to access AWS Route53.", err




#---------------------------------
# Launch Repository + Kick Server
#--------------------------------

# Prepare the cluster to be self-sufficient by installing directory called "launch".
# "launch" acts as a repository where each service will have its own sub-directory
# containing a Dockerfile, *.service file, and anything else it needs.
prepare_launch_directory = async (options) ->
  try
    command =
      "ssh -o \"StrictHostKeyChecking no\" core@#{options.hostname} << EOF\n" +
      "mkdir launch\n" +
      "mkdir launch/kick\n" +
      "EOF"

    output = yield execute command
    return build_success "The Launch Repository is ready.", output

  catch error
    return build_error "Unable to install the Launch Repository.", error


# Prepare the cluster to be self-sufficient by installing the Kick API server. (short for sidekick).
# It's a primative, meta API server that allows the cluster to alter itself independently
# of a remote agent.  The Kick server is Dockerized and contains the library of all Huxley mixins.
prepare_kick = async (options, creds) ->
  output = {}
  try
    # Place a copy of the kick-server Dockerfile on the cluster.
    command =
      "scp -o \"StrictHostKeyChecking no\" " +
      "#{__dirname}/launch/kick/Dockerfile " +
      "core@#{options.hostname}:/home/core/launch/kick/."

    output.dockerfile = yield execute command

    # Add the kick server to the cluster's private DNS records.
    params =
      hostname: "kick.#{options.dns}"
      zone_id: options.dns_zone_id
      type: "A"
      ip_address: options.private_ip_address

    {result, change_id} = yield add_dns_record params, creds
    output.register_kick = result
    output.detect_registration = yield poll_until_true get_dns_change_status,
      change_id, creds, 5000, "Unable to detect Kick registration."

    # Build the Kick's Docker container from its Dockerfile.
    command =
      "ssh -o \"StrictHostKeyChecking no\" core@#{options.hostname} << EOF\n" +
      "cd launch/kick\n" +
      "docker build --tag=\"kick_image\" .\n" +
      "EOF"

    output.build_kick = yield execute command

    # Activate the kick-server and pass in the user's AWS credentials.
    command =
      "ssh -o \"StrictHostKeyChecking no\" core@#{options.hostname} << EOF\n" +
      "docker run -d -p 2000:80 --name kick kick_image /bin/bash -c " +
      "\"echo \'id: \"#{creds.id}\"\' > panda-cluster-kick/kick.cson && " +
      "echo \'key: \"#{creds.key}\"\' >> panda-cluster-kick/kick.cson && " +
      "echo \'region: \"#{creds.region}\"\' >> panda-cluster-kick/kick.cson &&" +
      "source ~/.nvm/nvm.sh && nvm use 0.11 && " +
      "coffee --nodejs --harmony /panda-cluster-kick/kick.coffee\" \n" +
      "EOF"
    console.log command
    output.run_kick = yield execute command
    return build_success "The Kick Server is online.", output

  catch error
    console.log error
    return build_error "Unable to install the Launch Repository.", error




# # Helper function that launches a single unit from PandaCluster's library onto the cluster.
# launch_service_unit = async (name, hostname) ->
#   try
#     # Place a copy of the customized unit file on the cluster.
#     execute "scp #{__dirname}/services/#{name}  core@#{hostname}:/home/core/services/."
#
#     # Launch the service
#     command =
#       "ssh  core@#{hostname} << EOF\n" +
#       "fleetctl start launch/#{name}\n" +
#       "EOF"
#
#     execute command
#
#   catch error
#     return build_error "Unable to launch service unit.", error
#
#
# # Place a hook-server on the cluster that will respond to users' git commands
# # and launch githook scripts.  The hook-server is loaded with all cluster public keys.
# launch_hook_server = async (options) ->
#   try
#     config = options.hook_server
#
#     # Customize the hook-server unit file template.
#     # Add public SSH keys.
#
#     # Launch
#     yield launch_service_unit "hook-server.service", config.hostname
#
#   catch error
#     return build_error "Unable to install hook-server into cluster.", error


# After cluster formation is complete, launch a variety of services
# into the cluster from a library of established unit-files and AWS commands.
customize_cluster = async (options, creds) ->
  # Gather success data as we go.
  data = {}
  try
    # Set the specified hostname to the cluster's IP address.
    if options.hostname?
      {result, change_id} = yield set_hostname options, creds
      data.set_hostname = result
      data.detect_hostname = yield poll_until_true get_dns_change_status, change_id,
       creds, 5000, "Unable to detect DNS record change."
    else
      data.set_hostname = build_success "No hostname specified, using cluster IP Address.", options.ip_address
      options.hostname = options.ip_address

    # Establish a private DNS service available only on the cluster.
    {result, change_id, zone_id} = yield launch_private_dns options, creds
    options.dns_zone_id = zone_id
    data.launch_private_dns = result
    data.detect_private_dns_formation = yield poll_until_true get_dns_change_status,
      change_id, creds, 5000, "Unable to detect Private DNS formation."

    # Establish the Launch Repository and Bootstrap the Kick Server
    data.prepare_launch_directory = yield prepare_launch_directory options
    data.prepare_kick = yield prepare_kick options, creds

    return build_success "Cluster customizations are complete.", data

  catch error
    return build_error "Unable to properly configure cluster.", error




# Destroy a CoreOS cluster using the AWS account information that has been gathered.
destroy_cluster = async (params, creds) ->
  AWS.config = set_aws_creds creds
  cf = new AWS.CloudFormation()
  delete_stack = lift_object cf, cf.deleteStack

  try
    data = yield delete_stack params
    return true

  catch err
    throw build_error "Unable to access AWS Cloudformation.", err



#===============================
# PandaCluster Definition
#===============================
module.exports =

  # This method creates and starts a CoreOS cluster.
  create: async (options) ->
    credentials = options.aws
    credentials.region = options.region || credentials.region

    try
      # Make calls to Amazon's API. Gather data as we go.
      data = {}
      data.launch_stack = yield launch_stack(options, credentials)

      # Monitor the cluster until it is fully deployed.
      data.detect_formation = yield poll_until_true get_formation_status, options,
       credentials, 5000, "Unable to detect cluster formation."

      # Now that the cluster is fully formed, grab its IP address for later.
      {ip_address, private_ip_address} = yield get_cluster_ip_address( options, credentials)
      options.ip_address = ip_address
      options.private_ip_address = private_ip_address

      # Continue setting up the cluster.
      data.customize_cluster = yield customize_cluster( options, credentials)

      console.log  JSON.stringify data, null, '\t'
      return build_success "The requested cluster is online, configured, and ready.",
        data


    catch error
      console.log JSON.stringify error, null, '\t'
      return build_error "Apologies. The requested cluster cannot be created.", error




  # This method stops and destroys a CoreOS cluster.
  destroy: async (options) ->
    credentials = options.aws
    credentials.region = options.region || credentials.region

    # Build the "params" object that is used directly by the "createStack" method.
    params = {}
    params.StackName = options.stack_name

    #---------------------
    # Access AWS
    #---------------------
    # With everything in place, we may finally make a call to Amazon's API.
    try
      # Gather data as we go.
      data =
        destroy_cluster: yield destroy_cluster( params, credentials)

      return build_success "The targeted cluster has been destroyed.  All related resources have been released.",
      data

    catch error
      return build_error "Apologies. The targeted cluster has not been destroyed.", error
