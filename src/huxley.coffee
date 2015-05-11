#===============================================================================
# Panda-Cluster - Huxley Interface
#===============================================================================
# This file contains the code neccessary to signal the Huxley API with the cluster's
# status during formation and deletion.

{async} = require "fairmont"
{discover} = (require "pbx").client

module.exports =
  update: async (spec, status, details) ->
    spec.huxley.status = status
    spec.huxley.details = details

    try
      clusters = (yield discover spec.huxley.url).clusters
      yield clusters.put spec
    catch error
      throw new Error "Failed to update status. \n #{error}"
