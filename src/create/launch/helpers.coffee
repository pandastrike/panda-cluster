# Helpers for Huxley cluster launch method.
{async, collect, project} = require "fairmont"

{get, body} = (require "../../helpers").https

module.exports =
  # Wrapper for https call to etcd's discovery API.
  get_discovery_url: async -> yield body yield get "https://discovery.etcd.io/new"

  # Validate the SSH key name submitted to Huxley.  We cannot form a cluster
  # without a key that is known to the user's AWS account.
  validate: async (key, aws) ->
    {KeyPairs} = yield aws.ec2.describe_key_pairs {}
    names = collect project "KeyName", KeyPairs
    if key in names
      return true # Validated
    else
      throw "This AWS account does not have a key pair named \"#{key_name}\"."
