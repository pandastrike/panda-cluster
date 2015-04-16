#===============================================================================
# Panda-Cluster - Cluster Status Interface
#===============================================================================
# This file contains the code neccessary to signal the Huxley API with the cluster's
# status during formation and deletion.

{async} = require "fairmont"
{discover} = (require "pbx").client

module.exports = (config) ->

  update: async (spec) ->
    config.status = spec.status
    config.detail = spec.detail
    clusters = (yield discover config.huxley.url).clusters
    yield clusters.put config
