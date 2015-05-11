#===============================================================================
# panda-cluster - CloudFormation Template Construction
#===============================================================================
# This file pulls together various configuration data to produce a complete
# CloudFormation for a Huxley cluster.
{async, to_json} = require "fairmont"
{get, body} = (require "../../helpers").https

templates = require "./source"
vpc = require "./vpc"
security_group = require "./security-group"
autoscale = require "./autoscale"
user_data = require "./user-data"

module.exports =
  # Construct an AWS CloudFormation template and return it as a string.
  build: async (spec) ->
    # Start with a pre-prepared AWS template from CoreOS.
    url = templates[spec.coreos.channel][spec.cluster.virtualization]
    template = JSON.parse yield body yield get url

    # Augment the template with configuration details.
    template = vpc.add template, spec
    template = security_group.add template
    template = autoscale.add template, spec
    template = yield user_data.add template, spec

    # Construction complete. Return the template as stringified JSON.
    return to_json template, true
