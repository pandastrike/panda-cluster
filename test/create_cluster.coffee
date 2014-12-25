assert = require "assert"
amen = require "amen"
cli = require "./src/cli"
nock = require "nock"

# TODO: setup option to record or play, but lower priority
# decide whether we want to run real requests or not
#should_record = false
#argv = require('minimist')(process.argv.slice(2))
#if argv.record? is true
#  should_record = true

nock.recorder.rec
  dont_print: true
  output_objects: true
nock_calls = nock.recorder.play()
{read_file, write_file} = require "./file-rw"

assert true, read_file "./json/create-cluster/success.json"
assert true, write_file "./json/create-cluster/success.json", nock_recording
nock.load path



amen.describe "My simple test suite", (context) ->

  context.describe "My synchronous tests", (context) ->

  context.test "A simple test", -> assert true

  context.test "A nested test", (context) ->

    context.test "I'm nested!", -> assert true

  context.test "A failing test", -> assert false

  context.describe "My asynchronous tests", (context) ->

    # Two very contrived async functions

#    good = -> promise (resolve) -> setTimeout resolve, 100
#
#    bad = ->
#      promise (resolve, reject) ->
#        setTimeout (-> reject (new Error "oops")), 100
#
#    context.test "An asynchronous test", -> yield good()
#
#    context.test "A failing asynchronous test", -> yield bad()

    context.describe "creating a cluster", ->
      context.test "should return 200", ->
        response = yield cli.parse_cli "create", ["-n", "peter-cli-test", "k", "peter"]
        assert.equal 200, response.statusCode

