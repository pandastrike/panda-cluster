#===============================================================================
# panda-cluster - CloudFormation Template Construction
#===============================================================================
# This file pulls together various configuration data to produce a complete
# CloudFormation for a Huxley cluster.
{to_json} = require "fairmont"

vpc = require "./vpc"
security_group = require "./security-group"

module.exports =
  # Construct an AWS CloudFormation template and return it as a string.
  build: (spec) ->
    # Start with a bare-bones AWS template object.
    template = require "./template-base"

    # Augment the template with configuration details.
    template = vpc.add template, spec
    template = security_group.add template

    # Construction complete. Return the template as stringified JSON.
    return to_json template, true
