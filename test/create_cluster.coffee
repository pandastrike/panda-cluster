amen = require "amen"
cli = require "./src/cli"
async = (require "when/generator").lift

amen.describe "My simple test suite", async (context) ->

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

