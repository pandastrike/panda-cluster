#===============================================================================
# panda-cluster - Create
#===============================================================================
{async} = require "fairmont"

{update} = require "../huxley"
launch = require "./launch"
monitor = require "./monitor"
configure = require "./configure"

# Start and configure a cluster of cloud instances while monitoring state.
module.exports = async (spec) ->
  # Pull in the promise wrapped functions of the "aws-sdk" library.
  aws = (require "../aws")(spec.aws)
  try
    # Initiate cluster creation.
    yield update spec, "starting", "Launching Stack"
    yield launch spec, aws

    # Wait for cluster scaffolding to ready itself.
    spec = yield monitor spec, aws

    # Configure the cluster... Set basic DNS and install cluster agents
    yield configure spec, aws
    yield update spec, "online", "Cluster is ready."
  catch error
    yield update spec, "failed", "Error during creation."
    console.log error
    console.log line for line in (error.stack.split "\n")
