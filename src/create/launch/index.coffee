#===============================================================================
# panda-cluster - Create - Launch
#===============================================================================
# This file coordinates the actions of the Huxley cluster spinup in AWS.
{async} = require "fairmont"

ecs = require "../../ecs"
{validate, wait} = require "./helpers"

# Launch a Huxley cluster.
module.exports = async (spec, aws) ->
    # Validate that the named SSH key exists in the user's AWS account.
    yield validate spec.aws.key_name, aws

    # Establish an ECS cluster.
    spec = yield ecs.build spec, aws

    # Now wait for it to be ready to accept deployments.
    yield wait spec, aws

    return spec
