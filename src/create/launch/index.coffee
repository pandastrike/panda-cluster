#===============================================================================
# panda-cluster - Create - Launch
#===============================================================================
# This file coordinates the actions of the Huxley cluster spinup in AWS.
{async} = require "fairmont"

{cluster} = require "../../ecs"
template = require "../template"
{validate} = require "./helpers"

# Launch a Huxley cluster.
module.exports = async (spec, aws) ->
    # Validate that the named SSH key is associated with this account.
    yield validate spec.aws.key_name, aws

    # Establish an ECS cluster skeleton and wait for it to be ready (fast).
    spec = yield cluster.build spec, aws
    yield cluster.wait spec, aws

    # Establish a VPC.  CloudFormation and its template automates this for us...
    params = {}
    params.StackName = spec.cluster.name
    params.OnFailure = "DELETE"
    params.TemplateBody = yield template.build spec

    # Preparations complete.  Initiate formation.  This returns immediately, but
    # will take time to finish.
    yield aws.cloudformation.create_stack params
    return spec
