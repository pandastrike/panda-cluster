#===============================================================================
# panda-cluster - Create - Configure
#===============================================================================
# Configure the cluster: Set hostname, install cluster agent
{join} = require "path"
{async, read} = require "fairmont"
{render} = require "mustache"

{instance} = require "../../../ecs"
{record, hostedzone, confirm} = require "../../../dns"

module.exports = async (spec, aws) ->

  dns: async (spec, aws) ->
    # Create a *private* hosted zone on the cluster's VPC, allowing us to address internal components.
    yield update spec, "starting", "Creating Private DNS Hosted Zone."
    spec.cluster.dns.private.id = yield hostedzone.create {
        domain: spec.cluster.dns.private.name
        vpc: spec.cluster.vpc.id
        region: spec.aws.region
      },
      aws

    # Set the *public* hostname to point at the cluster's host's public IP address.
    # This is how the outside world will achieve authorized access to the cluster's agent.
    # Returns the "change ID" so we know when the DNS record is synchronized.
    return yield record {
        action: "set"
        hostname: "#{spec.cluster.name}.#{spec.cluster.dns.public.name}"
        id: spec.cluster.dns.public.id
        ip: spec.cluster.host.ip.public
      },
      aws


  install: async (spec, aws) ->
    # Establish a "host machine", one instance with the cluster's Huxley agent.
    host_type = "m3.medium"
    user_data = render (yield read join __dirname, "user-data.template"), spec
    host = yield instance.create {
        count: 1
        type: host_type
        price: 0
        virtualiziation: "hvm"
        availability_zone: spec.aws.availability_zone
        tags: [spec.cluster.tags[0], {Key: "Name", Value: "Host for #{spec.cluster.name}"}]
        user_data: new Buffer(user_data).toString('base64')
      },
      spec, aws

    spec.cluster.host = host[0]
    spec.cluster.host.type = host_type
    return spec
