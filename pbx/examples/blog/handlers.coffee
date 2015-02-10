async = (require "when/generator").lift
{call} = require "when/generator"
{Memory} = require "pirate"

pandacluster = require "../../../src/pandacluster"

_  = require "underscore"

deep_copy = (object) ->
  _.map(object, _.clone)[0]

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
      data = (yield data)
      cluster_url = make_key()
      {cluster_name, email, secret_token, key_pair, public_keys} = data
      user = yield users.get email

      if user && data.secret_token == user.secret_token
        cluster_entry =
          email: email
          url: cluster_url
          name: cluster_name
        cluster_res = yield clusters.put cluster_url, cluster_entry

        # FIXME: deep copy this bad boy
        #create_request = deep_copy user

        create_request = user
        create_request.stack_name = cluster_name

        # FIXME: removed yield in clusters.create
        res = pandacluster.create create_request
        # FIXME: delete field because "create_request = user" is shallow copy
        delete create_request.stack_name
        respond 201, "", {location: (url "cluster", {cluster_url})}
      else
        respond 401, "invalid email or token"

  cluster:

    # FIXME: pass in secret token in auth header
    delete: async ({respond, match: {path: {cluster_url}}, request: {headers: {authorization}}}) ->
      cluster = yield clusters.get cluster_url
      {email, name} = cluster
      user = yield users.get email
      # FIXME: validate secret token
      #if user && secret_token == user.secret_token
      if user
        request_data =
          aws: user.aws
          stack_name: name
        clusters.delete cluster_url
        # FIXME: removed yield in clusters.delete
        pandacluster.destroy request_data
      else
        respond 401, "invalid email or token"

    get: async ({respond, match: {path: {cluster_url}}, request: {headers: {authorization}}}) ->
      clusters = (yield clusters)
      cluster = (yield clusters.get cluster_url)
      console.log "*****get cluster: ", cluster
      {email} = cluster
      user = yield users.get email
      # FIXME: validate secret token
      #if user && secret_token == user.secret_token
      if user
        request_data =
          aws: user.aws
          stack_name: cluster.name
        cluster_status = yield pandacluster.get_cluster_status request_data
        respond 200, {cluster_status}
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
      console.log "*****create user data: ", data
      data.secret_token = key
      user = yield data
      user.secret_token = key
      console.log "*****user created: ", user
      yield users.put user.email, user
      respond 201, {user}
