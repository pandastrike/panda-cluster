# Any change to the DNS records takes time to propigate.  We need to wait until
# we can confirm that their status is "INSYNC".
{async, sleep} = require "fairmont"

query = async (id, aws) ->
  while true
    data = yield aws.route53.get_change {Id: id}
    if data.ChangeInfo.Status == "INSYNC"
      return true
    else
      yield sleep 5000


module.exports = async (changes, aws) ->
  yield query(id, aws) for id in changes
