#===============================================================================
# panda-cluster - CloudFormation Template Construction - User Data
#===============================================================================
# This file adds configuration details to the UserData section of the
# CloudFormation template, which allows us to send custom information to the
# instance during spinup.
{async} = require "fairmont"

# CoreOS configuration is handled through "cloud-config".
cloud_config = require "./cloud-config"

module.exports =
  add: async (template, spec) ->

    # Isolate the "UserData" array within the template.
    user_data = template.Resources.CoreOSServerLaunchConfig.Properties.UserData
    user_data = yield cloud_config.add user_data, spec

    # Place this array back into the template.
    template.Resources.CoreOSServerLaunchConfig.Properties.UserData = user_data
    return template
