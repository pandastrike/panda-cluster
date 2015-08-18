#===============================================================================
# panda-cluster - Create - Configure
#===============================================================================
# Configure the cluster: Establish host, install cluster agent, install registry
{async} = require "fairmont"

host = require "./host"
agent = require "./agent"
registry = require "./registry"
{update} = require "../../huxley"

module.exports = async (spec, aws) ->
  # Establish a "host machine", one instance with the cluster's Huxley agent.
  spec = yield host.install spec, aws
  yield update spec, "starting", "Cluster Host Machine Online."

  # As we proceed, gather a list of "change IDs" from DNS alterations.
  changes = []
  changes.push yield host.dns spec, aws
  changes.push yield agent.dns spec, aws
  changes.push yield registry.dns spec, aws

  # Install the cluster's Huxley agent.
  yield update spec, "starting", "Installing Huxley Agent."
  spec = yield agent.install spec, aws

  # Install the cluster's private Docker registry.
  yield update spec, "starting", "Installing Private Docker Registry."
  spec = yield registry.install spec, aws

  # Confirm all DNS records we've set are synchronized.  We poll here to
  # not block Docker setup while the DNS records are synchronized.
  yield update spec, "starting", "Confirming DNS Record Changes."
  yield confirm changes, aws
