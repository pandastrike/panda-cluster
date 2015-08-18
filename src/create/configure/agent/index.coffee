#===============================================================================
# panda-cluster - Huxley Agent
#===============================================================================
# The Huxley agent is a server that lives on the user's cluster.  It provides
# a reflective API, an interface allowing the cluster to alter the cloud
# infrastructure allocated to itself.

# The agent is accompanied by a private Docker registry, allowing the deployment
# of containers not on the public Internet.  Both the agent and registry are
# located on the cluster's "host machine" and are Dockerized.
{async, shell} = require "fairmont"

{record, domain} = require "../../../dns"
{task, service} = require "../../../ecs"
ssh_with_config = require "./ssh" # string with config details
environment = require "./env"

module.exports =

  dns: async (spec, aws) ->
  # Address the agent on the cluster's private hostedzone.  Return the "change ID"
  # to track when the DNS record is synchronized.
  {dns, host} = spec.cluster
  return yield record {
      action: "set"
      hostname: "kick.#{dns.private.name}"
      id: dns.private.id
      ip: host.ip.private
    },
    aws



  install: async (spec, aws) ->
    # Create an ECS Task Defintion for the Huxley agent.
    task = {}
    task.definition = yield task.create({
      family: "#{spec.cluster.name}-agent"
      name: "agent"
      image: "pandastrike/huxley_kick:v1.0.0-alpha-09"
      cpu: 512
      memory: 1500
      essential: true
      command: ["coffee", "--nodejs", "--harmony", "/panda-kick/src/server.coffee"]
      environment: environment
      ports: [
        containerPort: 8080,
        hostPort: 2000,
        protocol: "tcp"
      ]
    },
    spec, aws)


    task.id = yield task.start({
      instances: [ spec.cluster.host.id ]
      task: task.definition
      cluster: spec.cluster.cloud.id
      author: "Huxley"
      },
      spec, aws)

    spec.cluster.host.task = task
    return spec
