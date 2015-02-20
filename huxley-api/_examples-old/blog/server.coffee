{call} = require "when/generator"
processor = require "../../src/processor"
initialize = require "./handlers"
api = require "./api"

options =
  host: "127.0.0.1"
  port: 8080

api.base_url = "http://#{options.host}:#{options.port}"

call ->
  (require "http")
  .createServer yield (processor api, initialize)
  .listen options.port, ->
    console.log "pbx listening to #{api.base_url}"
