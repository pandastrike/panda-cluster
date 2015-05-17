# This code pertains to installing launch directories into every instance of the cluster.
{async, collect, map, shell} = require "fairmont"

module.exports =
  # Access every instance and place directories that are scratch space during deployment.
  install: async (instances) ->
    project = (x) -> x.ip.public
    for address in (collect map project, instances)
      yield shell "ssh -A " +
        "-o \"StrictHostKeyChecking no\" " +
        "-o \"UserKnownHostsFile=/dev/null\" " +
        "core@#{address} << EOF \n " +
        "mkdir launch \n" +
        "mkdir prelaunch \n" +
        "EOF"
