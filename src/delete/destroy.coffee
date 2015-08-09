# This file contains the code that calls the actual deletion functions.
{async} = require "fairmont"

{hostedzone} = require "../dns"
{update} = require "../huxley"

module.exports = async (spec, aws) ->
  yield update spec, "shutting down", "Deleting private hosted zone and hostname records."
  # Not everything gets deleted with a stack.  DNS records *may* remain.
  if spec.cluster.dns.private.id
    yield hostedzone.delete spec.cluster.dns.private.id, aws

  # Delete the CloudFormation Stack running our VPC.
  yield aws.cloudformation.delete_stack {StackName: spec.cluster.name}
  yield update spec, "shutting down", "CloudFormation stack deletion in progress."
