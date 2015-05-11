#===============================================================================
# panda-cluster - CloudFormation - User Data - Cloud Config
#===============================================================================
# Cloud-Config is a YAML document CoreOS uses to configure startup.  We add this
# to the "UserData" section of the CloudFormation template.  CoreOS calls each
# task it runs a "unit".
{async} = require "fairmont"

unit = require "./unit"
data = require "./formation-units/metadata"

module.exports =
  add: async (template, spec) ->
    # Isolate the "cloud-config" array within the template.
    config = template["Fn::Base64"]["Fn::Join"][1]

    # Add units to the cloud-config section (specified in the directory formation-units).
    for x of data
      config = yield unit.add config, data[x]

    # Add the specified public keys.  We must be careful with indentation formatting.
    if spec.public_keys
      config.push "ssh_authorized_keys: \n"
      for x in spec.public_keys
        config.push "  - #{x}\n"

    # Place this array back into the template.
    template["Fn::Base64"]["Fn::Join"][1] = config
    return template
