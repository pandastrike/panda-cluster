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

# When Library
{promise, lift} = require "when"
{liftAll} = require "when/node"
node_lift = (require "when/node").lift
async = (require "when/generator").lift

# ShellJS
{exec} = require "shelljs"

# Access AWS API
AWS = require "aws-sdk"


#================================
# Helper Functions
#================================
# Allow "when" to lift AWS module functions, which are non-standard.
lift_object = (object, method) ->
  node_lift method.bind object

# This is a wrap of setTimeout with ES6 technology that forces a non-blocking
# pause in execution for the specified duration (in ms).
pause = (duration) ->
  promise (resolve, reject) ->
    callback = -> resolve()
    setTimeout callback, duration

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

  response = yield https_get template_url
  template_object = JSON.parse (yield get_body response)

  return template_object

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
  content = read( resolve( __dirname, "services/#{unit.name}"))
  content = content.split "\n"

  while content.length > 0
    cloud_config.push "        " + content[0] + "\n"
    content.shift()

  return cloud_config



# Build an AWS CloudFormation template by augmenting the official ones released
# by CoreOS.  Return a JSON string.
build_template = async (options) ->
  # Pull official CoreOS template as a JSON object.
  template_object = yield pull_cloud_template options

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
      throw "\nError: This AWS account does not have a key pair named \"#{key_pair}\".\n\n"
    return true # validated

  catch err
    throw "\nError:  Unable to validate SSH key.\n #{err}\n\n"



# Launch the procces that eventually creates a CoreOS cluster using the AWS
# account information that has been gathered.
launch_stack = async (params, creds) ->
  AWS.config = set_aws_creds creds
  cf = new AWS.CloudFormation()
  create_stack = lift_object cf, cf.createStack

  try
    data = yield create_stack params
    return true

  catch err
    throw "\nApologies. Cluster formation has failed.\n\n#{err}\n"


# This function checks the specified AWS stack to see if its formation is complete.
# It returns either true or false, and throws an exception if an AWS error is reported.
get_formation_status = async (name, creds) ->
  AWS.config = set_aws_creds creds
  cf = new AWS.CloudFormation()
  describe_events = lift_object cf, cf.describeStackEvents

  try
    data = yield describe_events {StackName: name}

    if data.StackEvents[0].ResourceType == "AWS::CloudFormation::Stack" &&
    data.StackEvents[0].ResourceStatus == "CREATE_COMPLETE"
      return true
    else if data.StackEvents.ResourceStatus == "CREATE_FAILED"
      throw "\nApologies. Cluster formation has failed. "
    else
      return false

  catch err
    throw "\nApologies. Cluster formation has failed.\n\n#{err}\n"


# Cluster creation can take several minutes.  This function polls AWS until the
# CoreOS cluster is fully formed and ready for additional instructions.
detect_formation = async (name, creds) ->
  while !(yield get_formation_status(name, creds))
    yield pause 5000








# Associate the cluster's IP address with a domain the user owns via Route 53.
set_cluster_url = async (url, creds) ->
  # First, get the Domain Name
  split_url = url.split "."
  len = split_url.length
  domain = "#{split_domain[ len - 2 ]}.#{split_domain[ len - 1] }"

  # Now, the Hosted Zone ID
  AWS.config = set_aws_creds creds
  r53 = new AWS.Route53()
  list_zones = lift_object r53, r53.listHostedZones

  try
    data = yield list_zones {}

    names = pluck data.HostedZones, Name
    ids = pluck data.HostedZones, Id
    if url in names
      zone_id = ids[names.indexOf(url)]
    else
      throw "\nError: The specified domain is not associated with this account.\n"

  catch err
    throw err

  # Start building the params object for Route53 Record Set function.
  params =
    ChangeBatch: {
      Changes: [
      {
        Action: 'UPSERT',
        ResourceRecordSet: {
          Name: "#{url}", 
          Type: 'A',


# Using Private DNS from Route 53, we need to give the cluster a private DNS
# so services may be referenced with human-friendly names.
launch_dns = async (domain, creds) ->






# Prepare the cluster to accept customization.  This will likey get more complex
# in the future.
prepare_cluster = async (config) ->
  command =
    "ssh core@#{config.cluster_url} << EOF\n" +
    "mkdir services\n" +
    "EOF"

  exec command

# Helper function that launches a single unit from PandaCluster's library onto the cluster.
launch_service_unit = async (name, cluster_url) ->
  # Place a copy of the customized unit file on the cluster.
  exec "scp #{__dirname}/services/#{name}  core@#{cluster_url}:/home/core/services/."

  # Launch the service
  command =
    "ssh core@#{cluster_url} << EOF\n" +
    "fleetctl start services/#{name}\n" +
    "EOF"

  exec command


# Place a hook-server on the cluster that will respond to users' git commands
# and launch githook scripts.  The hook-server is loaded with all cluster public keys.
launch_hook_server = async (config) ->
  # Customize the hook-server unit file template.
  # Add public SSH keys.

  # Launch
  yield launch_service_unit "hook-server.service", config.cluster_url


# After cluster formation is complete, optionally launch a variety of services
# into the cluster from a library of established unit-files and AWS commands.
customize_cluster = async (options, creds) ->

  # Options that use AWS interface.
  yield set_cluster_url options.cluster_url, creds  if options.cluster_url?
  yield launch_dns options.dns, creds               if options.dns?

  # Options that use CoreOS service units.
  yield prepare_cluster options
  yield launch_hook_server options.hook_server      if options.hook_server?




# Destroy a CoreOS cluster using the AWS account information that has been gathered.
destroy_cluster = async (params, creds) ->
  AWS.config = set_aws_creds creds
  cf = new AWS.CloudFormation()
  delete_stack = lift_object cf, cf.deleteStack

  try
    data = yield delete_stack params
    return true

  catch err
    throw "\nApologies. Cluster destruction has failed.\n\n#{err}\n"

#===============================
# PandaCluster Definition
#===============================
module.exports =

  # This method creates and starts a CoreOS cluster.
  create: async (options) ->
    credentials = options.aws
    credentials.region = options.region || credentials.region

    # Build the "params" object that is used directly by the AWS "createStack" method.
    params = {}
    params.StackName = options.stack_name
    params.OnFailure = "DELETE"
    params.TemplateBody = yield build_template options

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
        "ParameterValue": options.key_pair if yield validate_key_pair( options.key_pair, credentials)
      }

      # AdvertisedIPAddress - uses default "private", TODO: Add this option
      # AllowSSHFrom        - uses default "everywhere", TODO: Add this option
    ]

    #---------------------
    # Access AWS
    #---------------------
    # With everything in place, we may finally make a call to Amazon's API.
    yield launch_stack( params, credentials)
    yield detect_formation( options.stack_name, credentials)
    #yield customize_cluster( options, credentials)
    return 201



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
    yield destroy_cluster( params, credentials)
    return 200
