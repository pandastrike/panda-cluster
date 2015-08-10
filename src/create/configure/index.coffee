#===============================================================================
# panda-cluster - Create - Configure
#===============================================================================
# Configure the cluster: Set hostname, install cluster agents
{join} = require "path"
{async, read} = require "fairmont"
{render} = require "mustache"

{instance} = require "../../ecs"
agent = require "./agents"
{record, hostedzone, confirm} = require "../../dns"
{update} = require "../../huxley"

module.exports = async (spec, aws) ->
  # Establish a "host machine", one instance with the cluster's Huxley agents.
  host_type = "m3.medium"
  user_data = render (yield read join __dirname, "user-data.template"), spec
  host = yield instance.create {
      count: 1
      type: host_type
      price: 0
      virtualiziation: "hvm"
      availability_zone: null
      user_data: new Buffer(user_data).toString('base64')
    },
    spec, aws

  spec.cluster.host = host
  spec.cluster.host.type = host_type


  # As we proceed, gather a list of "change IDs" from DNS alterations.
  changes = []

  # Set the public hostname to point at the cluster's host's public IP address.
  changes.push yield record {
      action: "set"
      hostname: "#{spec.cluster.name}.#{spec.cluster.dns.public.name}"
      id: spec.cluster.dns.public.id
      ip: spec.cluster.host.ip.public
    },
    aws

  # Create a private hosted zone to address internal components.
  yield update spec, "starting", "Creating Private Hosted Zone."
  spec.cluster.dns.private.id = yield hostedzone.create {
      domain: spec.cluster.dns.private.name
      vpc: spec.cluster.vpc.id
      region: spec.aws.region
    },
    aws

  # # Install the cluster's kick server agent.
  # yield update spec, "starting", "Installing Kick Server."
  # changes.push yield agent.kick.install spec, aws
  #
  # # Install the cluster's hook server agent.
  # yield update spec, "starting", "Installing Hook Server."
  # changes.push yield agent.hook.install spec, aws

  # Confirm all DNS records we've set are synchronized.  We poll here to
  # not block Docker setup while the DNS records are synchronized.
  yield update spec, "starting", "Confirming DNS Record Changes."
  yield confirm changes, aws
