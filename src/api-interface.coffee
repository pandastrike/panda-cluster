#===============================================================================
# Panda-Cluster - Cluster Status Interface
#===============================================================================
# This file contains the code neccessary to signal the Huxley API with the cluster's
# status during formation and deletion.

{async} = require "fairmont"
{discover} = require "./client"

module.exports = (config) ->

  update_status: async (spec) ->
    config.status = spec.status
    config.detail = spec.detail
    config.secret_token = spec.secret_token
    config.cluster_id = spec.cluster_id
    clusters = (yield discover config.huxley_url).clusters
    yield clusters.put config
    console.log "Status Update Complete"
