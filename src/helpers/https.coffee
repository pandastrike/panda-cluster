#===============================================================================
# panda-cluster - Helpers HTTPS
#===============================================================================
# This file provides promise wrappers for Node's HTTPS module so we may use them
# with the ES6 style.
https = require "https"
{promise} = require "when"

module.exports =

  # "Get" over HTTPS protocol.
  get: (url) ->
    promise (resolve, reject) ->
      https.get url
      .on "response", (response) ->
        resolve response
      .on "error", (error) ->
        reject error

  # Extract body data from response.  Assumes utf-8 encoding.
  body: (response) ->
    promise (resolve, reject) ->
      data = ""

      response.setEncoding "utf8"
      .on "data", (chunk) ->
        data = data + chunk
      .on "end", ->
        resolve data
      .on "error", (error) ->
        reject error
