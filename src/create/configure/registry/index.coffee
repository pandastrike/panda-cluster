#===============================================================================
# panda-cluster - Private Docker Registry
#===============================================================================
# The agent is accompanied by a private Docker registry, allowing the deployment
# of containers not on the public Internet.  We pull the officially supported
# image "registry" and run it without TLS security because only boxes within the
# cluster's VPC can reach it.
{async, shell} = require "fairmont"

{record, domain} = require "../../../dns"
{task, service} = require "../../../ecs"
ssh_with_config = require "./ssh" # string with config details

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
    spec = yield task.create({
      family: "#{spec.cluster.name}-agent"
      name: "agent"
      image: "pandastrike/huxley_kick:v1.0.0-alpha-09"
      cpu: 512
      memory: 1500
      essential: true
      command: ["coffee", "--nodejs", "--harmony", "/panda-kick/src/server.coffee"]
      environment: config.environment
      ports: [
        containerPort: 8080,
        hostPort: 2000,
        protocol: "tcp"
      ]
    },
    spec, aws)

    # Create an ECS Task Defintion for the cluster's private Docker registry.
    spec = yield task.create({
      family: "#{spec.cluster.name}-registry"
      name: "registry"
      image: "registry:2"
      cpu: 512
      memory: 1500
      essential: true
      command: ["coffee", "--nodejs", "--harmony", "/panda-kick/src/server.coffee"]
      environment: config.environment
      ports: [
        containerPort: 5000,
        hostPort: 2001,
        protocol: "tcp"
      ]
    },
    spec, aws)

    spec = yield service.create()





    # TODO: Replace this with a mustache.js template.
    zones.public.id = dns.public.id.split("/")[2]
    zones.public.name = domain.fully_qualify dns.public.name
    zones.private.id = dns.private.id.split("/")[2]
    zones.private.name = domain.fully_qualify dns.private.name

    yield shell ssh_with_config +
      "core@#{host.ip.public} << EOF\n" +
      "docker run -d -p 2000:8080 --name kick " +
      "pandastrike/huxley_kick:v1.0.0-alpha-03.1 /bin/bash -c " +


    return change

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
