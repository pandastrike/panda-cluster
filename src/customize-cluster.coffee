# After cluster formation is complete, launch a variety of services
# into the cluster from a library of established unit-files and AWS commands.
customize_cluster = async (options, creds) ->
  # Gather success data as we go.
  data = {}
  dns_changes = {}
  try
    #---------------
    # Hostname
    #---------------
    # Set the specified hostname to the cluster's IP address.
    options.public_domain = fully_qualified options.public_domain
    options.public_zone_id = yield get_public_zone_id( options.public_domain, creds)
    options.hostname = "#{options.cluster_name}.#{options.public_domain}"

    console.log "Registering Cluster in DNS"
    {result, change_id} = yield set_hostname options, creds
    data.set_hostname = result
    dns_changes.hostname = change_id

    #---------------
    # Private DNS
    #---------------
    options.private_domain = fully_qualified options.private_domain

    # Establish a private DNS service available only on the cluster.
    {result, change_id, zone_id} = yield create_private_domain options, creds
    console.log "Private DNS launched: #{options.private_domain} #{change_id} #{zone_id}"
    data.launch_private_domain = result
    options.private_zone_id = zone_id
    #data.detect_private_dns_formation = yield poll_until_true get_hosted_zone_status,
    #  change_id, creds, 5000, "Unable to detect Private DNS formation."
    #console.log "Private DNS fully online."

    #---------------------------------------------------
    # Launch Dir + Kick + Hook
    #---------------------------------------------------
    data.prepare_launch_directory = yield prepare_launch_directory options
    console.log "Launch Directory Created."

    result = yield prepare_kick options, creds
    data.prepare_kick = result.result
    dns_changes.kick = result.change_id
    console.log "Kick Server Online."

    result = yield prepare_hook options, creds
    data.prepare_hook = result.result
    dns_changes.hook = result.change_id
    console.log "Hook Server Online."

    #-----------------------------
    # Confirm DNS Changes
    #-----------------------------
    # We poll here to be more efficient.  Amazon should be done updating its DNS records
    # by the time we build all the built-in Docker stuff.  We shave two minutes off
    # our startup time, and just play it safe by double-checking here.
    data.detect_hostname = yield poll_until_true get_record_change_status, dns_changes.hostname,
     creds, 5000, "Unable to detect DNS record change."
    console.log "Cluster Hostname Set"

    data.detect_kick = yield poll_until_true get_record_change_status, dns_changes.kick,
     creds, 5000, "Unable to detect Kick registration.", 25
    console.log "Kick Hostname Set"

    data.detect_kick = yield poll_until_true get_record_change_status, dns_changes.hook,
     creds, 5000, "Unable to detect Kick registration.", 25
    console.log "Hook Hostname Set"


    return build_success "Cluster customizations are complete.", data
  catch error
    console.log error
    return build_error "Unable to properly configure cluster.", error
