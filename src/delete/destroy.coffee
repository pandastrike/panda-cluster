# This file contains the code that calls the actual deletion functions.
{async, empty, collect, project} = require "fairmont"

{hostedzone} = require "../dns"
{update} = require "../huxley"
{instance, cluster} = require "../ecs"

module.exports = async (spec, aws) ->
  # We cannot delete the VPC until we empty out its dependencies.

  # Search for DNS records.
  yield update spec, "shutting down", "Deleting Private DNS hosted zone and Hostname Records."
  if spec.cluster.dns.private.id
    yield hostedzone.delete spec.cluster.dns.private.id, aws

  # Find and terminate all cluster instances.
  yield update spec, "shutting down", "Terminating Cluster Instances."
  params = Filters: [ {Name: "vpc-id", Values: [spec.cluster.vpc.id] } ]
  data = yield aws.ec2.describe_instances params
  instances = collect project "InstanceId", data.Reservations[0].Instances
  yield instance.delete instances, aws  if !empty instances

  # Delete the ECS cluster skeleton.
  yield update spec, "shutting down", "Deleting ECS Framework."
  yield cluster.delete spec, aws

  # Delete the CloudFormation Stack running our VPC.
  yield update spec, "shutting down", "Deleting Cluster VPC"
  yield aws.cloudformation.delete_stack {StackName: spec.cluster.name}
