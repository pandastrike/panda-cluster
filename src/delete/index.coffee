#===============================================================================
# panda-cluster - Delete
#===============================================================================
# Terminate the specified cluster of instances and all associated resources.
{async} = require "fairmont"

{detect, identify} = require "./monitor"
destroy = require "./destroy"
{update, resolve} = require "../huxley"

module.exports = async (spec) ->
  # Pull in the promise wrapped functions of the "aws-sdk" library.
  aws = (require "../aws")(spec.aws)
  try
    # Before we delete the stack, we must identify associated resources. We can
    # use the the VPC's ID to track these.
    yield update spec, "shutting down", "Cluster VPC Lookup."
    spec = yield identify spec, aws

    # Delete the cluster.
    yield destroy spec, aws

    # Monitor the deletion and report when it is complete.
    yield detect spec, aws
    yield update spec, "stopped", "Cluster Is Fully Destroyed."
  catch error
    yield update spec, "failed", "Error during deletion."
    console.log error
    console.log line for line in (error.stack.split "\n")
