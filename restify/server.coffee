restify = require 'restify'

{lift} = require "when"
{call} = (require "when/generator")
async = (require "when/generator").lift

options =
  host: "127.0.0.1"
  port: 1337

server = restify.createServer
  name: 'pandacluster-api'
  version: '1.0.0'

server.use restify.acceptParser(server.acceptable)
server.use restify.queryParser()
server.use restify.bodyParser()

mongo = null
cluster = null

call ->
  Store = (require "./node_modules/pirate/src/index").Memory.Adapter
  #console.log "Store: ", Store
  adapter = new Store
  #console.log "adapter: ", adapter
  yield adapter.connect()

  Cluster = require "./src/cluster"
  Mongo = require "./src/mongo"
  mongo = new Mongo {adapter: adapter}
  cluster = new Cluster {datastore: mongo}

#  console.log "Mongo: ", Mongo
#  console.log "Cluster: ", Cluster
#  console.log "mongo: ", mongo
#  console.log "cluster: ", cluster


server.post "/clusters", async (req, res, next) ->
  try
    result = yield cluster.create_cluster {req: req}
    res.send 201, result
  catch error
    res.send 400, error
  next()

server.post "/cluster/:cluster_id", async (req, res, next) ->
  try
    result = yield cluster.destroy_cluster {req: req}
    res.send 201, result
  catch error
    res.send 400, error
  next()

# FIXME: async
server.post "/users", (req, res, next) ->
  console.log req.body
  try
    result = cluster.create_user {req: req}
    res.send 201, result
  catch error
    res.send 400, error
  next()


# FIXME: delete this feature, only for testing purposes
server.get '/users', (req, res, next) ->
  users = cluster.get_all_users()
  res.send 201, users
  next()

server.get '/echo/:name', (req, res, next) ->
  res.send req
  next()

server.get "/", (req, res, next) ->
  res.send "hello world!"
  next()

server.listen options.port, options.host, ->
  console.log '%s listening at %s', server.name, server.url
