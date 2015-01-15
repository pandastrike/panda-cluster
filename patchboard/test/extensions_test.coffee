GitHubClient = require("../client")
Testify = require("testify")
assert = require "assert"

helpers = require "./helpers"
client = new GitHubClient(helpers.login, helpers.password)

Testify.test "Resources from templatized urls", (context) ->

  context.test "User", (context) ->
    context.test ".get()", (context) ->
      user = client.resources.user(login: "dyoder")
      user.get (error, {resource}) ->

        context.test "received expected response", ->
          assert.ifError(error)

        context.test "response has resource of correct type", ->
          assert.equal resource.resource_type, "user"


  context.test "Repositories", (context) ->
    context.test ".list()", (context) ->
      user_repos = client.resources.user_repositories(login: "dyoder")
      user_repos.list (error, {resource}) ->

        context.test "received expected response", ->
          assert.ifError(error)

        context.test "response is an array", (context) ->
          assert.equal resource.constructor, Array
          context.test "items are all repositories", ->
            for item in resource
              assert.equal item.resource_type, "repository"






