{lift} = require "when"
async = (require "when/generator").lift
{discover} = require "./client"


module.exports =

  create_cluster: async ({cluster_name, email, secret_token, url}) ->

    api = (yield discover url)
    clusters = (api.clusters)
    {data} = (yield clusters.create {cluster_name, email, secret_token})
    data = (yield data)

#  get_cluster_status: async ({cluster_name, email, secret_token, url}) ->
#
#    api = (yield discover url)
#    clusters = (api.clusters)
#    {data} = (yield clusters.get_status {cluster_name, email, secret_token})
#    data = (yield data)

  get_cluster_status: async ({cluster_url, secret_token, url}) ->

    api = (yield discover url)
    cluster = (api.cluster cluster_url)
    {response} =
      (yield cluster.get())
    data = (yield response)

  # FIXME: filter out secret keys in response
  create_user: async ({aws, email, url, key_pair, public_keys}) ->

    api = (yield discover url)
    users = (api.users)
    {data} = (yield users.create {aws, email, key_pair, public_keys})
    data = (yield data)

  delete_cluster: async ({cluster_url, secret_token, url}) ->

    api = (yield discover url)
    cluster = (api.cluster cluster_url)
    {response} =
      (yield cluster.delete
        headers:
          Authorization: secret_token)
    data = (yield response)
