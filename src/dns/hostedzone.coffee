{async} = require "fairmont"

record_change = require "./record"

module.exports =
  # Use Route53 to create a private hosted zone within the VPC.
  create: async ({domain, vpc, region}, aws) ->
    params =
      CallerReference: vpc
      Name: domain
      VPC:
        VPCId: vpc
        VPCRegion: region

    data = yield aws.route53.create_hosted_zone params
    return data.HostedZone.Id

  delete: async (id, aws) ->
    # AWS does not allow the deletion of hosted zones with hostname records.
    data = yield aws.route53.list_resource_record_sets {HostedZoneId: id}

    # Delete all contained records that are not the two special ones.
    for record in data.ResourceRecordSets
      if record.Type != "SOA" && record.Type != "NS"
        yield record_change {
            id: id
            hostname: record.Name
            action: "delete"
          },
          aws

    # We may now safely delete the hosted zone.
    yield aws.route53.delete_hosted_zone {Id: id}
