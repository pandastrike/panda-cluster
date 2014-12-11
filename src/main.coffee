#===============================================================================
# PandaCluster - Awesome Command-Line Tool and Library to Manage CoreOS Clusters
#===============================================================================

#====================
# Modules
#====================
{argv} = process
{resolve} = require "path"
{read, write, remove} = require "fairmont" # Easy file read/write
{parse} = require "c50n"                   # .cson file parsing
{exec} = require "shelljs"                 # Access to commandline
sync_request = require "sync-request"      # Quick and Easy Sync http requests

AWS = require "aws-sdk"                    # Access AWS API



#====================
# Helper Fucntions
#====================
# Output an Info Blurb and optional message.
usage = (entry, message) ->
  if message?
    process.stderr.write "#{message}\n"

  process.stderr.write( read( resolve( __dirname, "..", "doc", entry ) ) )
  process.exit -1


# Extract AWS credientials from the PandaCluster dotfile.
extract_credentials = (path) ->
  credentials = parse( read( resolve( path )))
  return credentials.aws

#===============================
# Module Definition
#===============================
module.exports =
  # This method creates and starts a CoreOS cluster.
  create: (credentials, options) ->
    # Configure the AWS object for account access.
    AWS.config =
      accessKeyId: credentials.id
      secretAccessKey: credentials.key
      region: credentials.region
      sslEnabled: true

    # Build the "params" object that is used directly by the "createStack" method.
    params = {}
    params.StackName = options.stack_name
    params.Parameters = []
    params.TemplateBody = read( resolve( __dirname, "templates/stable"))
    params.OnFailure = "DELETE"

    #---------------------------------------------------------------------------
    # Parameters is a map of key/values custom defined for this stack in the
    # template file.  We will now fill these out as specified or with defaults.
    #---------------------------------------------------------------------------
    # InstanceType
    foo = options.instance_type or "m3.medium"
    bar =
      "ParameterKey": "InstanceType"
      "ParameterValue": foo
    params.Parameters.push bar

    # ClusterSize
    foo = options.cluster_size or "3"
    bar =
      "ParameterKey": "ClusterSize"
      "ParameterValue": foo
    params.Parameters.push bar

    # DiscoveryURL - Grab a randomized URL from etcd's free discovery service.
    foo = sync_request "GET", "https://discovery.etcd.io/new"
    foo = foo.getBody 'utf-8'
    bar =
      "ParameterKey": "DiscoveryURL"
      "ParameterValue": foo
    params.Parameters.push bar

    # KeyPair
    bar =
      "ParameterKey": "KeyPair"
      "ParameterValue": options.key_pair
    params.Parameters.push bar

    # AdvertisedIPAddress - uses default, TODO: Add this option
    # AllowSSHFrom        - uses default, TODO: Add this option



    #---------------------
    # Access AWS
    #---------------------
    # With everything in place, we may finally make a call to Amazon's API.

    cloudformation = new AWS.CloudFormation()
    cloudformation.createStack params, (err, data) ->
      if err
          process.stderr.write "\nApologies. Cluster formation has failed.\n\n#{err}\n"
          process.exit -1

      process.stdout.write "\nSuccess!!  Cluster formation is in progress.\n"
      process.stdout.write "StackID = #{data.StackID}\n"



  # This method stops and destroys a CoreOS cluster.
  destroy: (credentials, clusterName) ->
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
      if err
          process.stderr.write "\nApologies. Cluster destruction has failed.\n\n#{err}\n"
          process.exit -1

      process.stdout.write "\nSuccess!!  Cluster destruction is in progress.\n"


#===============================
# Command-Line
#===============================
#-------------------------------------------------------------------------------
# When PandaCluster is used as a command-line tool, we stil call the above module
# functions, but we have to build the the "options" object by parsing the
# command-line arguments.
#
# First, we define parsing functions for each sub-command.
#-------------------------------------------------------------------------------

# Create
parse_create_arguments = (argv) ->
  # Deliver an info blurb if neccessary.
  if argv.length == 1 or argv[1] == "-h" or argv[1] == "help"
    usage "create"
    process.exit -1

  # Begin buliding the "options" object.
  options = {}

  # Establish an array of flags that *must* be found for this method to succeed.
  required_flags = ["-k", "-n"]

  # Loop over arguments.  To preserve the argv array, we create a temporary copy first.
  foo = argv[1..]

  while foo.length > 0
    if foo.length == 1
      usage "create", "\nError: Flag Provided But Not Defined: #{foo[0]}\n"
      process.exit -1

    switch foo[0]
      when "-k"
        options.key_pair = foo[1]
        remove required_flags, "-k"
      when "-m"
        options.extra_space = foo[1]
      when "-n"
        options.stack_name = foo[1]
        remove required_flags, "-n"
      when "-s"
        options.cluster_size = foo[1]
      when "-t"
        options.instance_type = foo[1]
      when "-u"
        options.public_keys = parse( read( resolve( foo[1] )))
      else
        usage "create", "\nError: Unrecognized Flag Provided: #{foo[0]}\n"
        process.exit -1

    foo = foo[2..]

  # Done looping.  Check to see if all required flags have been defined.
  if required_flags.length != 0
    usage "create", "\nError: Mandatory Flag(s) Remain Undefined: #{required_flags}\n"
    process.exit -1

  # After successful parsing, return the completed "options" object.
  return options


# Destroy
parse_destroy_arguments = (argv) ->
  # Deliver an info blurb if neccessary.
  if argv.length == 1 or argv[1] == "-h" or argv[1] == "help" or argv.length > 2
    usage "destroy"
    process.exit -1

  # Build the "options" object.
  options = {}
  options.stack_name = argv[1]

  # After successful parsing, return the completed "options" object.
  return options


#-------------------------------------------------------------------------------
# Here, we begin examining the command-line, starting with a search for top-level sub-commands.
#-------------------------------------------------------------------------------
# Chop off the argument array so that only the arguments remain.
argv = argv[2..]

# Deliver an info blurb if neccessary.
if argv.length == 0 or argv[0] == "-h" or argv[0] == "help"
  usage "main"
  process.exit -1

# Now, look for the specified sub-command.
switch argv[0]
  when "create"
    credentials = extract_credentials "#{process.env.HOME}/.pandacluster.cson"
    options = parse_create_arguments argv
    module.exports.create credentials, options
  when "destroy"
    credentials = extract_credentials "#{process.env.HOME}/.pandacluster.cson"
    options = parse_destroy_arguments argv
    module.exports.destroy credentials, options
  else
    # When the command cannot be identified, display the help guide.
    usage "main", "\nError: Command Not Found: #{argv[0]} \n"
