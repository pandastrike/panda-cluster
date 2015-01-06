assert = require "assert"
{call} = require "when/generator"
cli = require "../src/cli"

call ->

  try
    #    console.log cli
#    response = yield cli.parse_cli "create", ["-n", "peter-cli-test", "-k", "peter"]
#    console.log response
#    assert.equal 201, response.statusCode

  catch error
    console.error error
