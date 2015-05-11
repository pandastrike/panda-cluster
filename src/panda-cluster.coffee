

delete_domain = async (zone_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    delete_zone = lift_object r53, r53.deleteHostedZone

    data = yield delete_zone {Id: zone_id}
    return build_success "The specified domain has been successfully deleted.", data

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53", error


# This function checks the specified Hosted Zone to see if its "INSYC", done updating.
# It returns either true or false, and throws an exception if an AWS error is reported.
get_hosted_zone_status = async (change_id, creds) ->
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    get_hosted_zone = lift_object r53, r53.getHostedZone

    try
      data = yield get_hosted_zone {Id: change_id}

      if data.ChangeInfo.Status == "INSYNC"
        return build_success "The private DNS is fully online.", data
      else
        return false

    catch err
      console.log error
      return build_error "Unable to access AWS Route53.", err

# This function will return the ID of the cluster's private Hosted Zone, provided the VPC ID.
get_private_zone_id = async (vpc_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_zones = lift_object r53, r53.listHostedZones

    data = yield list_zones {}

    # Dig the ID out of an array, holding an object, holding the string we need.
    return false if (where data.HostedZones, {CallerReference: vpc_id}).length == 0
    return where( data.HostedZones, {CallerReference: vpc_id})[0].Id

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error


# This function queries AWS for all the DNS records belonging to a particular Hosted Zone.
get_all_records = async (zone_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    get_records = lift_object r53, r53.listResourceRecordSets

    data = yield get_records {HostedZoneId: zone_id}

    records = []
    for x in data.ResourceRecordSets
      if x.Type != "SOA" && x.Type != "NS"
        records.push {
          hostname: x.Name
          type: x.Type
          value: x.ResourceRecords
        }

    return records

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error




# This function takes a HostedZone's ID and deletes it.
delete_hosted_zone = async (zone_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_zones = lift_object r53, r53.listHostedZones

    data = yield list_zones {}

    # Dig the ID out of an array, holding an object, holding the string we need.
    return where( data.HostedZones, {CallerReference: vpc_id})[0].Id

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error



#---------------------------
# Delete Cluster Functions
#---------------------------

# Delete the private domain associated with the specified cluster.
delete_private_domain = async (options, creds) ->
  try
    # Determine the Hosted Zone ID of the cluster's private domain.
    options.private_zone_id = yield get_private_zone_id options.vpc_id, creds
    return unless options.private_zone_id

    # Pull the list of DNS records within this Hosted Zone.
    zone_records = yield get_all_records options.private_zone_id, creds
    return if zone_records.length == 0

    # Delete these records
    for x in zone_records
      params =
        zone_id: options.private_zone_id
        hostname: x.hostname
        type: x.type
        value: x.value
      yield delete_dns_record params, creds

    # Finally, we may delete the private domain.
    data = yield delete_domain options.private_zone_id, creds
    return build_success "The specified domain has been successfully deleted.", data

  catch error
    console.log error
    return build_error "Failed to delete private domain.", error


# Delete the specified CoreOS cluster by deleting its CloudFormation Stack.
delete_stack = async (options, creds) ->
  try
    AWS.config = set_aws_creds creds
    cf = new AWS.CloudFormation()
    deleteStack = lift_object cf, cf.deleteStack

    data = yield deleteStack {StackName: options.cluster_name}
    return build_success "The cluster has been deleted.", data

  catch err
    throw build_error "Unable to access AWS Cloudformation.", err





#===============================
# PandaCluster Definition
#===============================
module.exports =

  # This method stops and deletes a CoreOS cluster.
  delete_cluster: async (options) ->
    credentials = options.aws
    credentials.region = options.region || credentials.region

    {update} = (require "./api-interface")(options)

    try
      # Make calls to Amazon's API. Gather data as we go.
      data = {}

      # Before we delete the stack, we must identify other resources associated with the cluster.
      # We can use the the ID of the VPC where the cluster resides.  Identify it.
      options.vpc_id = yield get_cluster_vpc_id options, credentials

      # Now delete the associated resources.
      data.delete_private_domain = yield delete_private_domain( options, credentials)
      yield update {status: "shutting_down", detail: "Cluster domain DNS records removed."}

      # Delete the CloudFormation Stack running our cluster.
      data.delete_stack = yield delete_stack( options, credentials)
      yield update {status: "stopped", detail: "CloudFormation stack deletion in progress."}

      console.log "Done. \n"
      return build_success "The targeted cluster has been destroyed.  All related resources have been released.",
      data

    catch error
      return build_error "Apologies. The targeted cluster has not been destroyed.", error
