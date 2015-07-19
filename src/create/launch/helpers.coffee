# Helpers for Huxley cluster launch method.
{async, sleep, collect, project} = require "fairmont"


module.exports =
  # Validate the SSH key name submitted to Huxley.  We cannot form a cluster
  # without a key that is known to the user's AWS account.
  validate: async (key, aws) ->
    {KeyPairs} = yield aws.ec2.describe_key_pairs {}
    names = collect project "KeyName", KeyPairs
    if key in names
      return true # Validated
    else
      throw new Error "This AWS account does not have a key pair named \"#{key}\"."

  # Wait for the ECS cluster to be capable of accepting deployments.
  wait: async (spec, aws) ->
    params = clusters: [ spec.cluster.name ]

    while true
      data = yield aws.ecs.describe_clusters params
      if data.clusters[0].status == "active"
        return true  # Cluster is ready
      else
        yield sleep 5000  # Needs more time.
