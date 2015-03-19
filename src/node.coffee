#===============================================================================
# Panda-Cluster - Lifted Node Functions
#===============================================================================
# This file provides common Node functions wrapped as promises so they may be used
# in the ES6 style.

{get} = require "https"
{promise} = require "when"

modules.export =
  # Promise wrapper around Node's https module. Turns GET calls into promises.
  https_get = (url) ->
    promise (resolve, reject) ->
      get url
      .on "response", (response) ->
        resolve response
      .on "error", (error) ->
        reject error

  # Promise wrapper around response events that read "data" from the response's body.
  get_body = (response, encoding) ->
    promise (resolve, reject) ->
      data = ""
      format = encoding || "utf8"

      response.setEncoding format
      .on "data", (chunk) ->
        data = data + chunk
      .on "end", ->
        resolve data
      .on "error", (error) ->
        reject error
