#===============================================================================
# Panda-Cluster - Cluster Status Interface
#===============================================================================
# This file contains the code neccessary to signal the Huxley API with the cluster's
# status during formation and deletion.

{async} = require "fairmont"
{discover} = require "./client"

module.exports = (config) ->

  update_status: async (spec) ->
    console.log "**Updating Cluster Status with API**"
    config.status = spec.status
    config.detail = spec.detail
    clusters = (yield discover config.huxley_url).clusters
    yield clusters.put config
    console.log "Status Update Complete"
