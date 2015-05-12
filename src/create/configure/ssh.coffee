# panda-cluster makes a multitude of SSH contacts with the cluster during
# configuration.  This module stores the configuration for that connection,
# which is basically a magic number.  We have a low tolerance for timeout and
# stay-alive interval because we need to detect a failure or deletion event.
module.exports =
  "ssh -A " +
  "-o \"StrictHostKeyChecking no\" " +
  "-o \"UserKnownHostsFile=/dev/null\" " +
  "-o \"ServerAliveInterval 10\" " +
  "-o \"ServerAliveCountMax 2\" " +
  "-o \"ConnectTimeout 10\""
