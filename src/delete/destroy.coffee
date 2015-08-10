# This file contains the code that calls the actual deletion functions.
{async} = require "fairmont"

{hostedzone} = require "../dns"
{update} = require "../huxley"
{instance} = require "../ecs"

module.exports = async (spec, aws) ->
  # We cannot delete the VPC until we empty out its dependencies.

  # Search for DNS records.
  yield update spec, "shutting down", "Deleting private hosted zone and hostname records."
  if spec.cluster.dns.private.id
    yield hostedzone.delete spec.cluster.dns.private.id, aws

  # Find and terminate all cluster instances.
  params = Filters: [ {Name: "vpc-id", Values: spec.cluster.vpc.id} ]
  data = yield aws.ec2.describe_instances params
  instances = collect project "InstanceId", data.Reservations[0].Instances
  yield instance.delete instances, aws

  # Delete the CloudFormation Stack running our VPC.
  yield aws.cloudformation.delete_stack {StackName: spec.cluster.name}
  yield update spec, "shutting down", "CloudFormation stack deletion in progress."
