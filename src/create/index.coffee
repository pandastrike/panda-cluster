#===============================================================================
# panda-cluster - Create
#===============================================================================
{async} = require "fairmont"

configure = require "./configure"
launch = require "./launch"
monitor = require "./monitor"
{update} = require "../huxley"   # Status updates to the Huxley API

# Start and configure a cluster of cloud instances while monitoring state.
module.exports = async (spec) ->
  # Pull in the promise wrapped functions of the "aws-sdk" library.
  aws = (require "../aws")(spec.aws)
  try
    # Create a blank cluster as specified. Augment "spec" with resulting component IDs and IP addresses.
    yield update spec, "starting", "Building Bare Cluster"
    spec = yield launch spec, aws

    # Configure the cluster: Set hostname, install cluster agents
    yield configure spec, aws
    yield update spec, "online", "Cluster is ready."
  catch error
    yield update spec, "failed", "Error during creation."
    console.log error
    console.log line for line in (error.stack.split "\n")
