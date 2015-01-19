restify = require 'restify'

{lift} = require "when"
async = (require "when/generator").lift

{randomKey} = require "key-forge"
keySize = 16 # bytes
key = randomKey keySize # defaults to hex encoding

cluster = require "./src/cluster"

options =
  host: "127.0.0.1"
  port: 1337

server = restify.createServer
  name: 'pandacluster-api'
  version: '1.0.0'

server.use restify.acceptParser(server.acceptable)
server.use restify.queryParser()
server.use restify.bodyParser()


server.post "/clusters", async (req, res, next) ->
  try
    result = yield cluster.create_cluster {cluster_name: "peter-cli-test"}
    res.send 201, result
  catch error
    res.send 400, error
  next()

server.post "/cluster/:cluster_id", async (req, res, next) ->
  try
    result = yield cluster.destroy_cluster {cluster_name: "peter-cli-test"}
  catch error
    res.send 400, error
  res.send 201, result

server.get '/echo/:name', (req, res, next) ->
  res.send req.params
  next()

server.get "/", (req, res, next) ->
  res.send "hello world!"
  next()

server.listen options.port, options.host, ->
  console.log '%s listening at %s', server.name, server.url
