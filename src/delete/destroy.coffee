# This file contains the code that calls the actual deletion functions.
{async} = require "fairmont"

{hostedzone} = require "../dns"

module.exports = async (spec, aws) ->
  console.log "Deleting private hosted zone and hostname records."
  # Not everything gets deleted with a stack.  DNS records *may* remain.
  if spec.cluster.zones.private.id
    yield hostedzone.delete spec.cluster.zones.private.id, aws

  # Delete the CloudFormation Stack running our cluster.
  yield aws.cloudformation.delete_stack {StackName: spec.cluster.name}
  console.log "CloudFormation stack deletion in progress."
