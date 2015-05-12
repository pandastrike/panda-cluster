#===============================================================================
# Panda-Cluster - Huxley Interface
#===============================================================================
# This file contains the code neccessary to signal the Huxley API with the cluster's
# status during formation and deletion.

{async} = require "fairmont"
{discover} = (require "pbx").client

module.exports =
  update: async (spec, status, details) ->
    spec.cluster.status = status
    spec.cluster.details = details

    try
      clusters = (yield discover spec.huxley.url).clusters
      yield clusters.put spec
    catch error
      throw new Error "Failed to update status. \n #{error}"

  # Determine the correct protocol to use to contact the API server.
  resolve: async (spec) ->
    if yield discover spec.huxley.url
      return spec
    else if (yield discover "http://#{spec.huxley.url}")
      spec.huxley.url = "http://#{spec.huxley.url}"
    else if (yield discover "https://#{spec.huxley.url}")
      spec.huxley.url = "https://#{spec.huxley.url}"
    else
      throw new Error "Unable to contact API server."

    return spec
