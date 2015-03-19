# Given a URL of many possible formats, return the root domain.
# https://awesome.example.com/test/42#?=What+is+the+answer  =>  example.com.
get_hosted_zone_name = (url) ->
  try
    # Find and remove protocol (http, ftp, etc.), if present, and get domain

    if url.indexOf("://") != -1
      domain = url.split('/')[2]
    else
      domain = url.split('/')[0]

    # Find and remove port number
    domain = domain.split(':')[0]

    # Now grab the root domain, the top-level-domain, plus what's to the left of it.
    # Be careful of tld's that are followed by a period.
    foo = domain.split "."
    if foo[foo.length - 1] == ""
      domain = "#{foo[foo.length - 3]}.#{foo[foo.length - 2]}"
    else
      domain = "#{foo[foo.length - 2]}.#{foo[foo.length - 1]}"

    # And finally, make the sure the root_domain ends with a "."
    domain = domain + "."
    return domain

  catch error
    return build_error "There was an issue parsing the requested hostname.", error


# Get the AWS HostedZoneID for the provided (fully specified) public domain.
get_public_zone_id = async (domain, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_zones = lift_object r53, r53.listHostedZones

    data = yield list_zones {}

    # Dig the ID out of an array, holding an object, holding the string we need.
    return where( data.HostedZones, {Name:domain})[0].Id


  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error



# Get the IP address currently associated with the hostname.
get_dns_record = async (hostname, zone_id, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    list_records = lift_object r53, r53.listResourceRecordSets

    data = yield list_records {HostedZoneId: zone_id}

    # We need to conduct a little parsing to extract the IP address of the record set.
    record = where data.ResourceRecordSets, {Name:hostname}

    if record.length == 0
      return {
        current_ip_address: null
        current_type: null
      }

    return {
      current_ip_address: record[0].ResourceRecords[0].Value
      current_type: record[0].Type
    }

  catch error
    console.log error
    return build_error "Unable to access AWS Route 53.", error



# Access Route 53 and alter an existing Route 53 record to a new IP address.
change_dns_record = async (options, creds) ->
  try
    # The params object contains "Changes", an array of actions to take on the DNS
    # records.  Here we delete the old record and add the new IP address.

    # TODO: When we establish an Elastic Load Balancer solution, we
    # will need to the "AliasTarget" sub-object here.
    params =
      HostedZoneId: options.zone_id
      ChangeBatch:
        Changes: [
          {
            Action: "DELETE",
            ResourceRecordSet:
              Name: options.hostname,
              Type: options.current_type,
              TTL: 60,
              ResourceRecords: [
                {
                  Value: options.current_ip_address
                }
              ]
          }
          {
            Action: "CREATE",
            ResourceRecordSet:
              Name: options.hostname,
              Type: options.type,
              TTL: 60,
              ResourceRecords: [
                {
                  Value: options.ip_address
                }
              ]
          }
        ]

    # We are ready to access AWS.
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    change_record = lift_object r53, r53.changeResourceRecordSets

    data = yield change_record params
    return {
      result: build_success "The hostname \"#{options.hostname}\" has been assigned to #{options.ip_address}.", data
      change_id: data.ChangeInfo.Id
    }

  catch error
    console.log error
    return build_error "Unable to assign the IP address to the designated hostname.", error


add_dns_record = async (options, creds) ->
  try
    # The params object contains "Changes", an array of actions to take on the DNS
    # records.  Here we delete the old record and add the new IP address.

    params =
      HostedZoneId: options.zone_id
      ChangeBatch:
        Changes: [
          {
            Action: "CREATE",
            ResourceRecordSet:
              Name: options.hostname,
              Type: options.type,
              TTL: 60,
              ResourceRecords: [
                {
                  Value: options.ip_address
                }
              ]
          }
        ]

    # We are ready to access AWS.
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    change_record = lift_object r53, r53.changeResourceRecordSets

    data = yield change_record params
    return {
      result: build_success "The hostname \"#{options.hostname}\" has been created and assigned to #{options.ip_address}.", data
      change_id: data.ChangeInfo.Id
    }

  catch error
    console.log error
    return build_error "Unable to assign the IP address to the designated hostname.", error


# Delete the specified DNS record.
delete_dns_record = async (options, creds) ->
  try
    params =
      HostedZoneId: options.zone_id
      ChangeBatch:
        Changes: [
          {
            Action: "DELETE",
            ResourceRecordSet:
              Name: options.hostname,
              Type: options.type,
              TTL: 60,
              ResourceRecords: options.value
          }
        ]

    # We are ready to access AWS.
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    change_record = lift_object r53, r53.changeResourceRecordSets

    data = yield change_record params
    return {
      result: build_success "The hostname \"#{options.hostname}\" has been deleted.", data
      change_id: data.ChangeInfo.Id
    }

  catch error
    console.log error
    return build_error "Unable to delete the designated hostname.", error



# This function checks the specified DNS record to see if it's "INSYC", done updating.
# It returns either true or false, and throws an exception if an AWS error is reported.
get_record_change_status = async (change_id, creds) ->
  AWS.config = set_aws_creds creds
  r53 = new AWS.Route53()
  get_change = lift_object r53, r53.getChange

  try
    data = yield get_change {Id: change_id}

    if data.ChangeInfo.Status == "INSYNC"
      return build_success "The DNS record is fully synchronized.", data
    else
      return false

  catch err
    console.log error
    return build_error "Unable to access AWS Route53.", err


# Given a hostname for the cluster, add a new or alter an existing DNS record that routes
# to the cluster's IP address.
set_hostname = async (options, creds) ->
  try
    # We need to determine if the requested hostname is currently assigned in a DNS record.
    {current_ip_address, current_type} = yield get_dns_record( options.hostname, options.public_zone_id, creds)

    if current_ip_address?
      console.log "Changing Current Record."
      # There is already a record.  Change it.
      params =
        hostname: options.hostname
        zone_id: options.public_zone_id
        current_ip_address: current_ip_address
        current_type: current_type
        type: "A"
        ip_address: options.instances[0].public_ip

      return yield change_dns_record params, creds
    else
      console.log "Adding New Record."
      # No existing record is associated with this hostname.  Create one.
      params =
        hostname: options.hostname
        zone_id: options.public_zone_id
        type: "A"
        ip_address: options.instances[0].public_ip

      return yield add_dns_record params, creds

  catch error
    console.log error
    return build_error "Unable to set the hostname to the cluster's IP address.", error



# Using Private DNS from Route 53, we need to give the cluster a private domain
# so services may be referenced with human-friendly names.
create_private_domain = async (options, creds) ->
  try
    AWS.config = set_aws_creds creds
    r53 = new AWS.Route53()
    create_zone = lift_object r53, r53.createHostedZone

    params =
      CallerReference: options.vpc_id
      Name: options.private_domain
      VPC:
        VPCId: options.vpc_id
        VPCRegion: creds.region

    data = yield create_zone params
    return {
      result: build_success "The Cluster's private DNS has been established.", data
      change_id: data.ChangeInfo.Id
      zone_id: data.HostedZone.Id
    }

  catch error
    console.log error
    return build_error "Unable to establish the cluster's private DNS.", error


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
