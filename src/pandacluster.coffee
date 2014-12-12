#===============================================================================
# PandaCluster - Awesome Command-Line Tool and Library to Manage CoreOS Clusters
#===============================================================================

#====================
# Modules
#====================
{resolve} = require "path"
{read, write, remove} = require "fairmont" # Easy file read/write
{parse} = require "c50n"                   # .cson file parsing
sync_request = require "sync-request"      # Quick and Easy Sync http requests

AWS = require "aws-sdk"                    # Access AWS API



#===============================
# PandaCluster Definition
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
    bar = sync_request "GET", "https://discovery.etcd.io/new"
    bar = bar.getBody 'utf-8'
    foo =
      "ParameterKey": "DiscoveryURL"
      "ParameterValue": bar
    params.Parameters.push foo

    # KeyPair
    foo =
      "ParameterKey": "KeyPair"
      "ParameterValue": options.key_pair
    params.Parameters.push foo

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
