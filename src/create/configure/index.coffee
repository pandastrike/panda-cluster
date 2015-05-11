#===============================================================================
# panda-cluster - Create - Configure
#===============================================================================
# Configure the cluster: Set hostname, install cluster agents
{async} = require "fairmont"

{launch, kick, hook} = require "./agents"
{record, hostedzone, confirm} = require "../../dns"

module.exports = async (spec, aws) ->
  # Acquire a rolling list of "change IDs" from DNS alterations.
  changes = []
  # Set the public hostname to point at the cluster's public IP address.
  changes.push yield record {
      action: "set"
      hostname: "#{spec.cluster.name}.#{spec.cluster.zones.public.name}"
      id: spec.cluster.zones.public.id
      ip: spec.cluster.instances[0].ip.public
    },
    aws


  # Create a private hosted zone to address internal components.
  spec.cluster.zones.private.id = yield hostedzone.create {
      domain: spec.cluster.zones.private.name
      vpc: spec.cluster.vpc_id
      region: spec.aws.region
    },
    aws

  # Install a launch directory into every machine in the cluster.
  yield launch.install spec.cluster.instances

  # Install the cluster's kick server agent.
  changes.push yield kick.install spec, aws

  # Install the cluster's hook server agent.
  changes.push yield hook.install spec, aws

  # Confirm all DNS records we've set are synchronized.  We poll here to
  # not block Docker setup while the DNS records are synchronized.
  console.log "Confirming DNS Record Changes."
  yield confirm changes, aws
