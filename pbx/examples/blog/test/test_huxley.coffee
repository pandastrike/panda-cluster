{call} = require "when/generator"
{discover} = require "../../../src/client"
amen = require "amen"
assert = require "assert"

cson = require "c50n"
{read} = require "fairmont"
{resolve} = require "path"


aws = null

call ->
  try
    aws = yield cson.parse (read(resolve("#{process.env.HOME}/.pandacluster.cson")))
  catch error
    assert.fail error, null, "Credential file ~/.pandacluster.cson missing"

amen.describe "Huxley API", (context) ->

  cluster_name = "peter-cli-test"
  email = aws.email
  secret_token = null
  cluster_url = null

  context.test "Create a user", (context) ->

    console.log "*****creating a user test"

    api = yield discover "http://localhost:8080"

    assert.ok api

    {response: {headers: {secret_token}}} =
      (yield api.users.create aws)

    assert.ok secret_token

    clusters = (api.clusters)

    assert.ok clusters

#    users = (api.users)
#
#    {response: {headers: {user}}} =
#      (yield users.get email)
#
#    console.log "*****user returned in test: ", user

    context.test "Create a cluster", ->

      console.log "*****creating a cluster test"

      {response: {headers: {cluster_url}}} =
        (yield clusters.create
            cluster_name: cluster_name
            secret_token: secret_token
            email: email)

      console.log "*****cluster_url: ", cluster_url
      assert.ok cluster_url

      cluster = (api.cluster cluster_url)

      console.log "*****cluster to delete client object: ", cluster.delete

      context.test "Delete a cluster", ->

        {response} =
          (yield cluster.delete
            data:
              secret_token: secret_token
              email: email)
