#===============================================================================
# panda-cluster - CloudFormation - User Data - Cloud Config - Units
#===============================================================================
# CoreOS schedules tasks with fleetctl and refers to them as units.  This
# directory contains special units used during cluster formation.

# Cloud-Config is a YAML file that provides metadata about each service,
# followed by the full text, itself.  Within the CloudFormation template, Cloud-
# Config exists as an array of each line.  YAML is sensitive to indentation, but
# JSON is not, so special care is required.
{resolve} = require "path"
{async, read} = require "fairmont"

module.exports =
  # Add unit to the cloud-config body.
  add: async (config, data) ->
    # Add to the cloud-config array.
    config.push "    - name: #{data.filename}\n"
    config.push "      runtime: #{data.runtime}\n"   if data.runtime
    config.push "      command: #{data.command}\n"   if data.command
    config.push "      enable: #{data.enable}\n"     if data.enable
    config.push "      content: |\n"

    # For "content", we draw from a unit-file maintained as a separate file.
    content = yield read resolve __dirname, "formation-units", data.filename
    content = content.split "\n"

    # Add eight spaces to the begining of each line (4 indentations) and follow
    # each line with an explicit new-line character.
    while content.length > 0
      config.push "        " + content[0] + "\n"
      content.shift()

    # Return the augmented array.
    return config
