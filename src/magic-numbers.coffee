#===============================================================================
# Panda-Cluster - Magic Numbers
#===============================================================================
# Magic Numbers are settings that are somewhat particular and hard-coded.  These
# have been grouped together here.

# Modules
{async} = require "fairmont"
{https_get, get_body} = require "./node"

#-----------------------
# Module Definition
#-----------------------
module.export =
  # Wrapper for https call to etcd's discovery API.  We need a URL to bootstrap etcd's setup process.
  get_discovery_url: async () ->
    yield get_body( yield https_get( "https://discovery.etcd.io/new"))

  # This function enforces defaults for configurations fed into panda-cluster's functions.
  # This is especially important for the "cluster_create" function because the configuration is so complex.
  enforce_config_defaults: (options, action) ->
    credentials = options.aws
    credentials.region = options.region || credentials.region  # allows temporary override of default region.

    if action? && action == "create"
      options.channel         ||= "stable"
      options.instance_type   ||= "m1.medium"
      options.cluster_size    ||= "3"
      options.virtualization  ||= "pv"
      options.private_domain  ||= "#{options.cluster_name}.cluster"

      options.cluster_size  = String(options.cluster_size)
      options.spot_price    = String(options.spot_price)     if options.spot_price?

    return {options, credentials}
