#===============================================================================
# PandaCluster - Awesome Command-Line Tool and Library to Manage CoreOS Clusters
#===============================================================================

#====================
# Modules
#====================
{resolve} = require "path"
{read, write} = require "fairmont"       # Easy file read/write
{parse} = require "c50n"                 # .cson file parsing

{promise} = require "when"               # Awesome promise library
{call} = require "when/generator"        # Uses ES6 generators to call promises
https = require "https"
#sync_request = require "sync-request"    # Quick and Easy Sync http requests

AWS = require "aws-sdk"                  # Access AWS API



#================================
# Helper Functions
#================================
# Promise wrapper around Node's https module to produce synchronous GET calls.
get_sync = (url) ->
  promise (resolve, reject) ->
    https.get url
    .on "response", (response) ->
      resolve response
    .on "error", (error) ->
      resolve error

# Pulls the most recent AWS CloudFormation template from CoreOS.
pull_cloud_template = ({channel, virtualization}) ->
  # Set reasonable defaults for these preferences.
  channel = channel or "stable"
  virtualization = virtualization or "pv"

  # This directory has a handy CSON file of URLs for CoreOS's latest CloudFormation templates.
  template_store = parse( read( resolve( __dirname, "templates.cson")))
  template_url = template_store[channel][virtualization]

  # TODO: Use ES6 here instead.
  #req = sync_request "GET", template_url
  #template_object = JSON.parse( req.getBody( 'utf-8'))
  response = yield get_sync template_url

  console.log response.body

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
  cloud_config.push "      enable: #{unit.enable}\n"       if unit.enable?
  cloud_config.push "      content: |\n"

  # For "content", we draw from a unit-file maintained in a separate file. Add
  # eight spaces to the begining of each line (4 indentations) and follow each
  # line with an explicit new-line character.
  content = read( resolve( unit.content))
  content = content.split "\n"

  while content.length > 0
    cloud_config.push "        " + content[0] + "\n"
    content.shift()

  return cloud_config


# Confirm that the named SSH key exists in your AWS account.  Assumes that the
# AWS object has already been configured with your credentials.
validate_key_pair = (key_pair) ->
  ec2 = new AWS.EC2()

  ec2.describeKeyPairs {}, (err, data) ->
    unless err
      names = []
      for key in data.KeyPairs
        names.push key.KeyName

      if names.indexOf(key_pair) == -1
        process.stderr.write "\nError: This AWS account does not have a key pair named \"#{key_pair}\".\n\n"
        process.exit -1

    else
      process.stderr.write "\nError:  Unable to validate SSH key.\n"
      process.stderr.write "#{err}\n\n"
      process.exit -1


#===============================
# PandaCluster Definition
#===============================
module.exports =

  # This method builds an AWS CloudFormation template by augmenting the official ones
  # released by CoreOS.
  build_template: (options) ->

    options = options or {}

    # Pull official CoreOS template as a JSON object.
    template_object = pull_cloud_template options

    # Isolate the cloud-config array within the JSON object.
    user_data = template_object.Resources.CoreOSServerLaunchConfig.Properties.UserData
    cloud_config = user_data["Fn::Base64"]["Fn::Join"][1]

    # Add the specified units to the cloud-config section.
    if options.units?
      for x in options.units
        cloud_config = add_unit cloud_config, x

    # Place this array back into the JSON object.  Construction complete.
    user_data["Fn::Base64"]["Fn::Join"][1] = cloud_config
    template_object.Resources.CoreOSServerLaunchConfig.Properties.UserData = user_data

    # Return or write the JSON object to a file.
    if options.write_path?
      write "#{process.cwd()}/#{options.write_path}", JSON.stringify( template_object, null, '\t' )
      return
    else
      return template_object



  # This method creates and starts a CoreOS cluster.
  create: (credentials, options) ->
    # Configure the AWS object for account access.
    AWS.config =
      accessKeyId: credentials.id
      secretAccessKey: credentials.key
      region: options.region or credentials.region
      sslEnabled: true

    # Build the "params" object that is used directly by the "createStack" method.
    params = {}
    params.StackName = options.stack_name
    params.OnFailure = "DELETE"

    #------------------------
    # TemplateBody Paramter
    #------------------------
    # This object is either drawn from either a specified JSON file or a basic default pulled from online.
    if options.template_path?
      params.TemplateBody = read( resolve( process.cwd(), options.template_path))
    else
      params.TemplateBody = @build_template()

    #---------------------------------------------------------------------------
    # Parameters is a map of key/values custom defined for this stack in the
    # template file.  We will now fill these out as specified or with defaults.
    #---------------------------------------------------------------------------
    params.Parameters = []

    # InstanceType
    foo =
      "ParameterKey": "InstanceType"
      "ParameterValue": options.instance_type or "m3.medium"
    params.Parameters.push foo

    # ClusterSize
    foo =
      "ParameterKey": "ClusterSize"
      "ParameterValue": options.cluster_size or "3"
    params.Parameters.push foo

    # DiscoveryURL - Grab a randomized URL from etcd's free discovery service.
    # TODO: Use ES6 here instead.
    #bar = sync_request "GET", "https://discovery.etcd.io/new"
    bar = bar.getBody 'utf-8'
    foo =
      "ParameterKey": "DiscoveryURL"
      "ParameterValue": bar
    params.Parameters.push foo

    # KeyPair
    validate_key_pair options.key_pair
    foo =
      "ParameterKey": "KeyPair"
      "ParameterValue": options.key_pair
    params.Parameters.push foo

    # AdvertisedIPAddress - uses default "private", TODO: Add this option
    # AllowSSHFrom        - uses default "everywhere", TODO: Add this option



    #---------------------
    # Access AWS
    #---------------------
    # With everything in place, we may finally make a call to Amazon's API.

    cloudformation = new AWS.CloudFormation()
    cloudformation.createStack params, (err, data) ->
      if !err
        process.stdout.write "\nSuccess!!  Cluster formation is in progress.\n"
        process.stdout.write "StackID = #{data.StackID}\n"

      else
        process.stderr.write "\nApologies. Cluster formation has failed.\n\n#{err}\n"
        process.exit -1





  # This method stops and destroys a CoreOS cluster.
  destroy: (credentials, options) ->
    # Configure the AWS object for account access.
    AWS.config =
      accessKeyId: credentials.id
      secretAccessKey: credentials.key
      region: credentials.region
      sslEnabled: true

    # Build the "params" object that is used directly by the "createStack" method.
    params = {}
    params.StackName = options.stack_name

    #---------------------
    # Access AWS
    #---------------------
    # With everything in place, we may finally make a call to Amazon's API.

    cloudformation = new AWS.CloudFormation()
    cloudformation.deleteStack params, (err, data) ->
      if !err
        process.stdout.write "\nSuccess!!  Cluster destruction is in progress.\n"

      else
        process.stderr.write "\nApologies. Cluster destruction has failed.\n\n#{err}\n"
        process.exit -1
