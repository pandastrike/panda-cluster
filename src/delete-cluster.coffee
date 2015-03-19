# Delete the private domain associated with the specified cluster.
delete_private_domain = async (options, creds) ->
  try
    # Determine the Hosted Zone ID of the cluster's private domain.
    options.private_zone_id = yield get_private_zone_id options.vpc_id, creds

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
