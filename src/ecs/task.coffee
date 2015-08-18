#===============================================================================
# panda-cluster - ECS Task
#===============================================================================
# This file provides an interface to handle ECS tasks.
{async, collect, project, map, sleep} = require "fairmont"

module.exports =

  # Create a task definition, but don't start it yet.
  create: async (config, spec, aws) ->
    params =
      family: config.family
      containerDefinitions: [
      {
        name: config.name
        image: config.image
        cpu: config.cpu
        memory: config.memory
        portMappings: config.ports
        essential: config.essential
        command: config.command
        environment: config.environment
      }
      ]

    data = yield aws.ecs.register_task_definition params
    return data.taskDefinition[0].taskDefinitionArn

  # Activate an existing task definition on a specified instance(s).
  start: async (config, spec, aws) ->
    params =
      containerInstances: config.instances
      taskDefinition: config.task
      cluster: config.cluster
      startedBy: config.author

    data = yield aws.ecs.start_task params
    return data.tasks[0].taskArn


  # Wait for the task's containers to be online and ready.
  wait: async (ids, spec, aws) ->
    is_active = (x) -> x == "RUNNING"
    is_failed = (x) -> x == null || x == "STOPPED"

    params =
      tasks: [ ids ]
      cluster: config.cluster

    while true
      data = yield aws.describe_tasks params
      states = collect project "lastStatus", data.tasks

      states.push null if states.length < ids.length
      success = collect map is_active states
      failure = collect map is_failed states

      if false !in success
        return true  # Tasks are ready.
      else if true in failure
        throw new Error "There was a task that failed to start properly."  # Task failure
      else
        yield sleep 5000  # Still pending
