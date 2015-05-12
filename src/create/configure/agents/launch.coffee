# This code pertains to installing launch directories into every instance of the cluster.
{async, collect, map, shell} = require "fairmont"
ssh_with_config = require "../ssh" # string with config details

module.exports =
  # Access every instance and place directories that are scratch space during deployment.
  install: async (instances) ->
    project = (x) -> x.ip.public
    for address in (collect map project, instances)
      yield shell ssh_with_config +
        "core@#{address} << EOF \n " +
        "mkdir launch \n" +
        "mkdir prelaunch \n" +
        "EOF"
