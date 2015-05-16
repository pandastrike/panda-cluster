# When we use Route53 to make DNS record changes, we submit an array of
# operations to perform on the record listings.  These are processed in
# a batch by AWS.
{async, collect, where, empty, sleep} = require "fairmont"

deletion = (record, hostname) ->
  return {
    Action: "DELETE",
    ResourceRecordSet:
      Name: hostname,
      Type: record[0].Type,
      TTL: 60,
      ResourceRecords: [ Value: record[0].ResourceRecords[0].Value ]
  }

creation = (ip, hostname, type) ->
  return {
    Action: "CREATE",
    ResourceRecordSet:
      Name: hostname
      Type: type || "A"
      TTL: 60
      ResourceRecords: [ Value: ip ]
  }

# Return an array of DNS change operations.
module.exports = async ({id, hostname, ip, action}, aws) ->
  # List of DNS operations.
  changes = []

  # There is an inconsistently appearing error where the change commands are not
  # set properly.  For now, we will try to settle for a "sleep" command until we
  # can find a proper solution.
  yield sleep 10000

  # Does the requested record exist?
  data = yield aws.route53.list_resource_record_sets {HostedZoneId: id}
  record = collect where {Name: hostname}, data.ResourceRecordSets
  console.log record
  if !empty record
    # When there is an existing record we must "DELETE" it before moving on.
    changes.push deletion record, hostname

  if action == "set"
    # "CREATE" the requested record.
    changes.push creation ip, hostname

  return changes
