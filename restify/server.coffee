restify = require 'restify'
pandacluster = require "../src/pandacluster"
cson = require "c50n"
{call} = require "when/generator"
{read} = require "fairmont"
{resolve} = require "path"
node_lift = (require "when/node").lift
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

# TODO: move to separate file

try
  aws = cson.parse (read(resolve("#{process.env.HOME}/.pandacluster.cson")))
catch error
  assert.fail error, null, "Credential file ~/.pandacluster.cson missing"

request_data =
  public_keys: aws.public_keys
  stack_name: "peter-cli-test"
  ephemeral_drive: "/dev/xvdb"
  key_pair: "peter"
  formation_units: [
    {
      name: "format-ephemeral.service"
      runtime: true
      command: "start",
    },
    {
      name: "var-lib-docker.mount"
      runtime: true
      command: "start"
    }
  ]
  aws: aws.aws

server.post "/clusters", async (req, res, next) ->
  try
    console.log "trying to post to cluster: ",  pandacluster
    result = yield pandacluster.create request_data
    res.send 201, result
  catch error
    res.send 400, error
  next()

server.get '/echo/:name', (req, res, next) ->
  res.send req.params
  next()

server.get "/", (req, res, next) ->
  console.log "getting shit"
  res.send "hello world!"
  next()

server.listen options.port, options.host, ->
  console.log '%s listening at %s', server.name, server.url
