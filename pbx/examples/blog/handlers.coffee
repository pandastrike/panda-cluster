async = (require "when/generator").lift
{call} = require "when/generator"
{Memory} = require "pirate"

pandacluster = require "../../../src/pandacluster"

make_key = -> (require "key-forge").randomKey 16, "base64url"

adapter = Memory.Adapter.make()


module.exports = async ->

  clusters = yield adapter.collection "clusters"
  users = yield adapter.collection "users"

  clusters:

    ###
    cluster: cluster_url
      email: String
      url: String
      name: String
    ###
    create: async ({respond, url, data}) ->
      data = yield data
      cluster_url = make_key()
      {cluster_name, email, secret_token} = data
      user = yield users.get email
      if user && data.secret_token == user.secret_token
        cluster_entry =
          email: email
          url: cluster_url
          name: cluster_name
        cluster_res = yield clusters.put cluster_url, cluster_entry
        create_request = user
        create_request.stack_name = cluster_name
        # FIXME: uncomment
        #res = yield pandacluster.create create_request
        respond 201, "", cluster_url: url "cluster", {cluster_url}
      else
        respond 401, "invalid email or token"

  cluster:

    #delete: async ({respond, match: {path: {cluster_url}}, data}) ->
    delete: async (block) ->
      body = yield block
      console.log "*****secret token: ", yield block.secret_token
      console.log "*****email: ", yield block.email
      console.log "*****block: ", body
      console.log "*****delete data1: ", data
      data = yield data
      console.log "*****delete cluster url: ", cluster_url
      console.log "*****delete data2: ", data
      user = yield users.get data.email
      if user && data.secret_token == user.secret_token
        cluster = yield clusters.get cluster_url
        request_data =
          aws: user.aws
          stack_name: cluster.name
        yield clusters.delete cluster_url
        pandacluster.delete request_data
        respond 200
      else
        respond 401, "invalid email or token"

  users:

    # FIXME: testing purposes only, delete after
    get: async ({respond, match: {path: {email}}, data}) ->
      console.log email
      user = yield users.get email
      console.log "****get users request", user
      respond 200, "", {user}

    ###
    user: email
      public_keys: Array[String]
      key_pair: String
      aws: Object
      email: String
    ###
    create: async ({respond, url, data}) ->
      key = make_key()
      data.secret_token = key
      user = yield data
      user.secret_token = key
      yield users.put user.email, user
      respond 201, "", secret_token: key
