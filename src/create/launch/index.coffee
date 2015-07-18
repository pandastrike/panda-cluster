#===============================================================================
# panda-cluster - Create - Launch
#===============================================================================
# This file coordinates the actions of the Huxley cluster spinup in AWS.
{async} = require "fairmont"

{validate, wait} = require "./helpers"
vpc = require "../../vpc"
{demand, spot} = require "../../instances"

# Launch a Huxley cluster.
module.exports = async (spec, aws) ->
    # Validate that the named SSH key exists in the user's AWS account.
    yield validate spec.aws.key_name, aws

    # Establish a VPC and its components.
    spec = yield vpc.build spec, aws

    # Launch the EC2 instances, specified in the instances array, into the VPC.
    for id, group of spec.cluster.resources
      switch group.class
        when "EC2 spot request" then spec = yield spot.create id, spec, aws
        when "EC2 on demand"    then spec = yield demand.create id, spec, aws
        else throw new Error "Unknown cluster resource descriptor."

    # Now wait until all of them are ready,
    yield wait spec, aws

    return spec
