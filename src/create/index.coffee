#===============================================================================
# panda-cluster - Create
#===============================================================================
{async} = require "fairmont"

configure = require "./configure"
launch = require "./launch"
monitor = require "./monitor"
{update} = require "../huxley"

# Start and configure a cluster of cloud instances while monitoring state.
module.exports = async (spec) ->
  # Pull in the promise wrapped functions of the "aws-sdk" library.
  aws = (require "../aws")(spec.aws)
  try
    # Initiate cluster creation.
    yield update spec, "starting", "Launching Stack"
    yield launch spec, aws

    # Monitor the cluster spinup.  Augment "spec" with resulting component IDs and IP addresses.
    spec = yield monitor spec, aws

    # Configure the cluster: Set hostname, install cluster agents
    yield configure spec, aws
    yield update spec, "online", "Cluster Is Ready."
  catch error
    yield update spec, "stopped", error
    console.log error
    console.log line for line in (error.stack.split "\n")
