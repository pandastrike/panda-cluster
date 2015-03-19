# Prepare the cluster to be self-sufficient by installing directory called "launch".
# "launch" acts as a repository where each service will have its own sub-directory
# containing a Dockerfile, *.service file, and anything else it needs.  Because we
# don't know which machine will host the service, copies of the launch directory need
# to be on every machine.
prepare_launch_directory = async (options) ->
  output = []
  try
    for address in pluck( options.instances, "public_ip")
      # Dump the repo's launch directory on the cluster.
      command =
        "ssh -A -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile=/dev/null\" " +
        "core@#{address} << EOF \n " +
        "mkdir launch \n" +
        "mkdir prelaunch \n" +
        "EOF"


      output.push yield execute command

    return build_success "The Launch Repositories are ready.", output
  catch error
    return build_error "Unable to install the Launch Repository.", error


# Prepare the cluster to be self-sufficient by launching the Kick API server on the "main"
# cluster machine.  This is short for "sidekick service"; a primative, meta API server that allows
# the cluster to act with some autonomy when prompted by a remote agent.  The Kick server is Dockerized.
prepare_kick = async (options, creds) ->
  output = {}
  try
    # Add the kick server to the cluster's private DNS records.
    params =
      hostname: "kick.#{options.private_domain}"
      zone_id: options.private_zone_id
      type: "A"
      ip_address: options.instances[0].private_ip[0]

    console.log "Adding Kick Server to DNS Record"
    {result, change_id} = yield add_dns_record( params, creds)
    output.register_kick = result

    console.log "Building Kick Container...  This will take a moment."
    # Pull the Kick's Docker container from the public repo.
    command =
      #"ssh -A -o \"StrictHostKeyChecking no\" -o \"LogLevel=quiet\" -o \"UserKnownHostsFile=/dev/null\" " +
      "ssh -A -o \"StrictHostKeyChecking no\"  -o \"UserKnownHostsFile=/dev/null\" " +
      "core@#{options.instances[0].public_ip} << EOF\n" +
      "docker pull pandastrike/pc_kick \n" +
      "EOF"

    output.build_kick = yield execute command

    # Activate the kick server and pass in the user's AWS credentials.  We need to get the
    # credentials *into* the kick server at runtime and obey CSON formatting rules.  That's
    # why we rely on a runtime `sed` command to make it happen while avoiding placing the user
    # credentials in multiple places.  They exist only in the running container and are *NOT*
    # stored in the image.
    public_zone_id = options.public_zone_id.split("/")[2]
    private_zone_id = options.private_zone_id.split("/")[2]

    command =
      "ssh -A -o \"StrictHostKeyChecking no\" -o \"LogLevel=quiet\" -o \"UserKnownHostsFile=/dev/null\" " +
      "core@#{options.instances[0].public_ip} << EOF\n" +
      "docker run -d -p 2000:80 --name kick pandastrike/pc_kick /bin/bash -c " +
      "\"cd panda-cluster-kick && " +

      "sed \"s/aws_id_goes_here/#{creds.id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/aws_key_goes_here/#{creds.key}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/aws_region_goes_here/#{creds.region}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/public_zone_id_goes_here/#{public_zone_id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/public_zone_name_goes_here/#{options.public_domain}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/private_zone_id_goes_here/#{private_zone_id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/private_zone_name_goes_here/#{options.private_domain}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "coffee --nodejs --harmony kick.coffee\" \n" +
      "EOF"

    output.run_kick = yield execute command
    return {
      result: build_success "The Kick Server is online.", output
      change_id: change_id
    }

  catch error
    return build_error "Unable to install the Kick Server.", error


# Prepare the cluster to be self-sufficient by launching the Hook server on the "main"
# cluster machine.  This is short for "git webhook"; a server that launches arbitary
# scripts based on user interactions via git, which acts over SSH.
prepare_hook = async (options, creds) ->
  output = {}
  try
    # Add the kick server to the cluster's private DNS records.
    params =
      hostname: "hook.#{options.private_domain}"
      zone_id: options.private_zone_id
      type: "A"
      ip_address: options.instances[0].private_ip[0]

    console.log "Adding Hook Server to DNS Record"
    {result, change_id} = yield add_dns_record( params, creds)
    output.register_kick = result


    console.log "Building Hook Container...  This will take a moment."
    # Pull the Hook Server's Docker container from the public repo.
    command =
      #"ssh -A -o \"StrictHostKeyChecking no\" -o \"LogLevel=quiet\" -o \"UserKnownHostsFile=/dev/null\" " +
      "ssh -A -o \"StrictHostKeyChecking no\"  -o \"UserKnownHostsFile=/dev/null\" " +
      "core@#{options.instances[0].public_ip} << EOF\n" +
      "docker pull pandastrike/pc_hook \n" +
      "EOF"

    output.build_hook = yield execute command

    #----------------------------
    # Activate the hook server.
    #----------------------------
    command =
      "ssh -A -o \"StrictHostKeyChecking no\" -o \"LogLevel=quiet\" -o \"UserKnownHostsFile=/dev/null\" " +
      "core@#{options.instances[0].public_ip} << EOF\n" +
      "docker run -d -p 3000:22 -p 2001:80 --name hook pandastrike/pc_hook /bin/bash -c \""

    # Pass in public keys so users may have access.
    for key in options.public_keys
      command = command + " echo \'#{key}\' >> root/.ssh/authorized_keys && "

    # Have the server generate host keys, then activate the SSH server in non-
    # detached mode, which keeps the container online.  We also need to use
    # the setting "UsePAM no".  Otherwise, there is some bug in Docker that
    # causes a connection failure with PAM in place.
    command = command +
      "ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N ''      && " +
      "ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N ''      && " +
      "ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N ''    && " +
      "ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N ''  && " +
      "mkdir /root/repos && " +
      "mkdir /root/passive && " +
      "/usr/sbin/sshd -e -o 'UsePAM no' && " +
      "git daemon --port=80 --base-path=/root --export-all \"\n" +
      "EOF"

    output.run_hook = yield execute command
    return {
      result: build_success "The Hook Server is online.", output
      change_id: change_id
    }

  catch error
    console.log error
    return build_error
