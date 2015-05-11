#===============================================================================
# panda-cluster - DNS
#===============================================================================
# This directory manages panda-cluster's DNS powers.  These functions wrap the
# Route53 API and provide a clean way to manipulate DNS records.
{async} = require "fairmont"

module.exports =
  hostedzone: require "./hostedzone"
  record: require "./record"
  confirm: require "./confirm"
