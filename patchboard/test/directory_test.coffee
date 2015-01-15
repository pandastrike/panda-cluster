GitHubClient = require("../client")
Testify = require("testify")
assert = require "assert"

helpers = require "./helpers"
client = new GitHubClient(helpers.login, helpers.password)

{repositories, authenticated_user, organizations} = client.resources
Testify.test "Resources provided full URLs by the directory", (context) ->

  context.test "the authenticated user", (context) ->
    authenticated_user.get (error, {resource}) ->
      context.test "successful request", ->
        assert.ifError(error)

       context.test "expected resource", ->
         assert.equal resource.resource_type, "user"
         assert.equal resource.name, "Matthew King"

  context.test "Own repositories", (context) ->
    repositories.list (error, {resource}) ->

      context.test "successful request", ->
        assert.ifError(error)

        context.test "response is an array", (context) ->
          assert.equal resource.constructor, Array
          context.test "items are all repositories", ->
            for item in resource
              assert.equal item.resource_type, "repository"

  context.test "Own orgs", (context) ->
    organizations.list (error, {resource}) ->

      context.test "successful request", ->
        assert.ifError(error)

      context.test "response is an array", (context) ->
        assert.equal resource.constructor, Array
        context.test "items are all organizations", ->
          for item in resource
            assert.equal item.resource_type, "organization"


