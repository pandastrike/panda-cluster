{lift} = require "when"
async = (require "when/generator").lift
{discover} = require "./client"


module.exports =

  create_cluster: async ({cluster_name, email, secret_token, url}) ->

    api = (yield discover url)
    clusters = (api.clusters)
    {response: {headers: {location}}}  = (yield clusters.create {cluster_name, email, secret_token})
    location

#  get_cluster_status: async ({cluster_name, email, secret_token, url}) ->
#
#    api = (yield discover url)
#    clusters = (api.clusters)
#    {data} = (yield clusters.get_status {cluster_name, email, secret_token})
#    data = (yield data)

  get_cluster_status: async ({cluster_url, secret_token, url}) ->

    api = (yield discover url)
    cluster = (api.cluster cluster_url)
    {data} = (yield cluster.get())
    data = (yield data)

  # FIXME: filter out secret keys in response
  create_user: async ({aws, email, url, key_pair, public_keys}) ->

    api = (yield discover url)
    users = (api.users)
    {data} = (yield users.create {aws, email, key_pair, public_keys})
    data = (yield data)

  delete_cluster: async ({cluster_url, secret_token, url}) ->

    api = (yield discover url)
    console.log "*****pbx controller cluster_url: ", cluster_url
    cluster = (api.cluster cluster_url)
    result = (yield cluster.delete headers: Authorization: secret_token)
    console.log "*****result of delete: ", result
    console.log "*****end of pbx.coffee delete, doesn't print out"
