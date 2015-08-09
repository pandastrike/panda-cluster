#===============================================================================
# panda-cluster - Create - Monitor
#===============================================================================
# During cluster creation, this code is used to monitor the status, and to halt
# things if there is an error or deletion (through Huxley or the AWS Console).
{async} = require "fairmont"

{detect, identify} = require "./cluster"
{update} = require "../../huxley"

module.exports = async (spec, aws) ->
  # Detect when the cluster successfully deploys or fails.
  yield detect spec, aws

  # Retrieve data about the successfully deployed cluster.
  spec = yield identify spec, aws

  yield update spec, "starting", "VPC Formation Complete"
  return spec
