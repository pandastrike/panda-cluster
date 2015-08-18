# This code pertains to the hook-server.  Huxley clusters are relatively
# self-sufficient through their use of cluster agents.  One of these agents is
# the hook-server.  This is short for "githook (or git webhook) server", a
# server that launches arbitary scripts based on user interactions via git,
# which acts over SSH.  The hook-server is launched on the "head" cluster
# machine and is Dockerized.
{async, shell} = require "fairmont"

{record} = require "../../../dns"
ssh_with_config = require "./ssh" # string with config details

module.exports =
  # Access the head instance and load the agent's Docker image.
  install: async (spec, aws) ->
    {dns, host} = spec.cluster
    # Address the kick server on the cluster's private hostedzone.
    change = yield record {
        action: "set"
        hostname: "hook.#{dns.private.name}"
        id: dns.private.id
        ip: host.ip.private
      },
      aws

    # Pull the hook-server's Docker container from the public repo.
    yield shell ssh_with_config +
      "core@#{host.ip.public} << EOF\n" +
      "docker pull pandastrike/huxley_hook:v1.0.0-alpha-06 \n" +
      "EOF"

    #----------------------------
    # Activate the hook server.
    #----------------------------
    command = ssh_with_config +
      "core@#{host.ip.public} << EOF\n" +
      "docker run -d -p 3000:22 -p 2001:80 --name hook " +
      "pandastrike/huxley_hook:v1.0.0-alpha-06 /bin/bash -c \""

    # Pass in public keys so users may have access.
    for key in spec.public_keys
      command = command + " echo \'#{key}\' >> root/.ssh/authorized_keys && "

    # Add the cluster agent private key so the hook server can access the host.
    command += " echo \'#{spec.cluster.agent.private}\' >> root/.ssh/id_rsa && " +
      " chmod 400 root/.ssh/id_rsa && "

    # Have the server generate host keys, then activate the SSH server in non-
    # detached mode, which keeps the container online.  We also need to use
    # the setting "UsePAM no".  Otherwise, there is some bug in Docker that
    # causes a connection failure with PAM in place.

    # Also, startup a git server so we may pull from repos in this container.
    command = command +
      "ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N ''      && " +
      "ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N ''      && " +
      "ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N ''    && " +
      "ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N ''  && " +
      "/usr/sbin/sshd -e -o 'UsePAM no' && " +
      "git daemon --port=80 --base-path=/root --export-all \"\n" +
      "EOF"

    yield shell command
    return change
