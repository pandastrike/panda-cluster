#===============================================================================
# panda-cluster - Create - Launch
#===============================================================================
# This file coordinates the actions of the Huxley cluster spinup in AWS.
{async} = require "fairmont"

template = require "../template"
{get_discovery_url, validate} = require "./helpers"

# Launch a Huxley cluster.
module.exports = async (spec, aws) ->
    # Create a "params" object for CloudFormation.
    params = {}
    params.StackName = spec.cluster.name
    params.OnFailure = "DELETE"
    params.TemplateBody = yield template.build spec

    #---------------------------------------------------------------------------
    # Parameters is a map of key/values custom defined for this stack by the
    # template file.  We will now fill out the map as specified or with defaults.
    #---------------------------------------------------------------------------
    params.Parameters = [
      # InstanceType
      "ParameterKey": "InstanceType"
      "ParameterValue": spec.cluster.type
    , # ClusterSize
      "ParameterKey": "ClusterSize"
      "ParameterValue": spec.cluster.size
    , # DiscoveryURL - Grab a randomized URL from etcd's free discovery service.
      "ParameterKey": "DiscoveryURL"
      "ParameterValue": yield get_discovery_url()
    ,# KeyPair
      "ParameterKey": "KeyPair"
      "ParameterValue": spec.aws.key_name if yield validate spec.aws.key_name, aws
    ]

    # Preparations complete.  Launch.
    yield aws.cloudformation.create_stack params
