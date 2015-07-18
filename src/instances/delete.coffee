# Instance Termination
#===============================================================================
# Regardless of how they are created, terminating an EC2 instance permanetly
# stops and deallocates the resources associated with an instance.

{async} = require "fairmont"

# ids is an array of one or more isntances that should be terminated.
module.exports = async (ids, spec, aws) ->
