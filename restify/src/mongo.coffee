{randomKey} = require "key-forge"
{lift} = require "when"
{call} = (require "when/generator")
{async} = (require "when/generator").lift
cson = require "c50n"

make_key = -> randomKey 16, "base64url"

# FIXME: need to bcrypt aws credentials
user = ({email, aws, public_keys, secret_token}) ->
  email: email
  clusters: {}
  secret_token: secret_token
  aws: aws
  public_keys: public_keys

###
  clusters:
    email: String
    {
      url: String
      cluster_name: String
    }
###

cluster = ({url, cluster_name}) ->
  url: url
  cluster_name: cluster_name

is_valid_token = (secret_token, user) ->
  user.secret_token == secret_token

module.exports = class Mongo

  constructor: ({adapter}) ->
    #@users = yield adapter.collection "users"
    @users = {}

  get_all_users: ->
    console.log "*****all users: ", @users
    @users

  # FIXME: placeholder in-memory, can't get pirate to work
  # FIXME: make async
  # create a user
  create_user: ({body}) ->
    console.log "*****create user body: ", body
    {email, aws, public_keys} = cson.parse body
    console.log "1.7"
    secret_token = make_key()
    console.log "1.8"
    new_user = user({
      email: email
      secret_token: secret_token
      email: email
      aws: aws
      public_keys: public_keys
    })
    console.log "1.9"
    @users[email] = new_user
    console.log "2"
    new_user
    #yield @users.put (user {email: email, secret_token: make_key()})

  # FIXME: make async
  create_cluster: ({body}) ->
    {email, cluster_name, secret_token} = cson.parse body
    user = @users[email]
    if user
      #if is_valid_token secret_token, user
      if true
        # FIXME: add in cluster url after testing
        #cluster_url = make_key()
        cluster_url = "123"
        new_cluster = cluster
          url: cluster_url
          cluster_name: cluster_name
        user.clusters[cluster_name] = new_cluster
        return user
      else
        throw new Error "Invalid email or secret token"
    else
      throw new Error "No user matching #{email}"
    #yield @users.put (user {email: email, secret_token: make_key()})

  # FIXME: make async
  destroy_cluster: ({body, params}) ->
    {cluster_url} = params
    {email, secret_token} = cson.parse body
    user = @users[email]
    request_data =
      user: user
      cluster_name: null
    if user
      #if is_valid_token secret_token, user
      if true
        console.log "*****destroy cluster: is true"
        for cluster_name, cluster of user.clusters
          console.log "*****cluster_name: ", cluster_name
          console.log "*****cluster: ", cluster
          console.log "*****cluster_url: ", cluster_url
          if cluster.url == cluster_url
            request_data.cluster_name = cluster_name
            console.log "*****request_data should have cluster_name: ", request_data
            delete @users[email].clusters[cluster_name]
        return request_data
      else
        throw new Error "Invalid email or secret token"
    else
      throw new Error "No user matching #{email}"

#  user:
#
#    # get a user
#    get: async ({match: {path}, respond, url}) ->
#      respond 200, (yield @users.get path.key)
#
#    # create a blog
#    create: async ({respond, url, match: {path}})->
#      user = JSON.parse yield @users.get path.key
#      if user?
#        blog = Blog.make()
#        user.blogs ?= []
#        user.blogs.push blog
#        yield @users.put path.key, (JSON.stringify user)
#        respond 201, "", location: url("blog", key: blog.key)
#      else
#        respond 404, "Not Found"
