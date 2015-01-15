Client = require("patchboard-js")

exports.saneTimeout = (ms, fn) -> setTimeout(fn, ms)

exports.discover = (callback) ->

  Client.discover "http://localhost:1979/", (error, client) ->
    throw error if error
    callback client


