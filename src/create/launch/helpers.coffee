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
