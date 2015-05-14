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
      data = yield clusters.update spec
      console.log data
    catch error
      throw new Error "Failed to update status. \n #{error}"
