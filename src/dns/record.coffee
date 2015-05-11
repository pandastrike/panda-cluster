{async, where, collect, empty} = require "fairmont"

{fully_qualify} = require "./domain"
changes = require "./changes"

# Given a hostname and an IP address, setup a DNS record.
module.exports = async ({id, hostname, ip, action}, aws) ->
  # Prepare "params" to request a DNS change from AWS.
  hostname = fully_qualify hostname
  change_list = yield changes {id, hostname, ip, action}, aws
  params =
    HostedZoneId: id
    ChangeBatch: Changes: change_list

  if !empty change_list
    data = yield aws.route53.change_resource_record_sets params
    return data.ChangeInfo.Id
  else
    return null
