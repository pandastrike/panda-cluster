{call} = require "when/generator"
{discover} = require "../../../src/client"

call ->
  try
    pandaconfig = yield cson.parse (read(resolve("#{process.env.HOME}/.pandacluster.cson")))
  catch error
    assert.fail error, null, "Credential file ~/.pandacluster.cson missing"

api = yield discover pandaconfig.url

module.exports =

  create_cluster: ({cluster_name, secret_token, email}) ->

    clusters = (api.clusters)
    {response} = (yield clusters.create {cluster_name, secret_token, email})
    response

  create_user: (config) ->

    users = (api.users)
    {response} = (yield users.create config)
    response

  delete_cluster: ({cluster_url, secret_token}) ->
    cluster = (api.cluster cluster_url)
    {response} =
      (yield cluster.delete
        headers:
          Authorization: secret_token)
    response
          
