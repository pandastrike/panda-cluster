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
        delete create_request.stack_name
        console.log "*****user in create cluster: ", user
        respond 201, "", cluster_url: url "cluster", {cluster_url}
      else
        respond 401, "invalid email or token"

  cluster:

    # FIXME: pass in secret token in auth header
    delete: async ({respond, match: {path: {cluster_url}}, secret_token}) ->
      cluster = yield clusters.get cluster_url
      console.log "*****cluster retrieved during delete: ", cluster
      {email} = cluster
      user = yield users.get email
      console.log "*****user retrieved during delete: ", user
      # FIXME: validate secret token
      #if user && secret_token == user.secret_token
      if user
        cluster = yield clusters.get cluster_url
        request_data =
          aws: user.aws
          stack_name: cluster.name
        yield clusters.delete cluster_url
        pandacluster.destroy request_data
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
      secret_token: String
    ###

    create: async ({respond, url, data}) ->
      key = make_key()
      data.secret_token = key
      user = yield data
      user.secret_token = key
      console.log "*****user created: ", user
      yield users.put user.email, user
      respond 201, "", secret_token: key
