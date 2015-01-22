{lift} = require "when"
async = (require "when/generator").lift
pandacluster = require "../../src/pandacluster"

cson = require "c50n"


module.exports = class Cluster

  constructor: ({datastore}) ->
    @mongo = datastore

  # FIXME: must receive deletion confirmation from AWS before removing from database
  destroy_cluster: async ({req}) ->
    data = @mongo.destroy_cluster req
    {cluster_name, user} = data
    request_data =
      aws: user.aws
      stack_name: cluster_name
    console.log "*****this is the request data: ", request_data
    yield pandacluster.destroy request_data

  # FIXME: must receive creation confirmation from AWS before adding to database
  create_cluster: async ({req}) ->
    user = @mongo.create_cluster req
    {cluster_name} = cson.parse req.body
    request_data =
      public_keys: user.public_keys
      key_pair: "peter"
      aws: user.aws
      stack_name: cluster_name
    result = yield pandacluster.create request_data
    result.cluster_url = user.clusters[cluster_name].url
    result

  # FIXME: async
  # FIXME: move to separate file "user.coffee"
  create_user: ({req}) ->
    console.log "1"
    new_user = @mongo.create_user req
    console.log "3"
    new_user

  get_all_users: ->
    @mongo.get_all_users()



