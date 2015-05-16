# This code pertains to the kick-server.  Huxley clusters are relatively
# self-sufficient through their use of cluster agents.  One of these agents is
# the kick-server.  This is short for "sidekick server", a primative, meta API
# server that allows the cluster to act with some autonomy when prompted by
# services on the cluster.  The kick-server is launched on the "head" cluster
# machine and is Dockerized.
{async, shell} = require "fairmont"

{record, domain} = require "../../../dns"
ssh_with_config = require "../ssh" # string with config details

module.exports =
  # Access the head instance and load the agent's Docker image.
  install: async (spec, aws) ->
    {zones, instances} = spec.cluster
    # Address the kick server on the cluster's private hostedzone.
    change = yield record {
        action: "set"
        hostname: "kick.#{zones.private.name}"
        id: zones.private.id
        ip: instances[0].ip.private
      },
      aws

    # Pull the kick-server's Docker container from the public repo.
    yield shell ssh_with_config +
      "core@#{instances[0].ip.public} << EOF\n" +
      "docker pull pandastrike/huxley_kick:v1.0.0-alpha-06 \n" +
      "EOF"


    # Activate the kick server and pass in the user's AWS credentials.  We need
    # to get the credentials *into* the kick server at runtime and obey CSON
    # formatting rules.  That's why we rely on a runtime `sed` command to make
    # it happen while avoiding placing the user credentials in multiple places.
    # They exist only in the running container and are *NOT* stored in the image.

    # TODO: Replace this with a mustache.js template.
    zones.public.id = zones.public.id.split("/")[2]
    zones.public.name = domain.fully_qualify zones.public.name
    zones.private.id = zones.private.id.split("/")[2]
    zones.private.name = domain.fully_qualify zones.private.name

    yield shell ssh_with_config +
      "core@#{instances[0].ip.public} << EOF\n" +
      "docker run -d -p 2000:8080 --name kick " +
      "pandastrike/huxley_kick:v1.0.0-alpha-06 /bin/bash -c " +
      "\"cd panda-kick/config &&  " +

      "sed \"s/aws_id_goes_here/#{spec.aws.id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/aws_key_goes_here/#{spec.aws.key}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/aws_region_goes_here/#{spec.aws.region}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/public_zone_id_goes_here/#{zones.public.id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/public_zone_name_goes_here/#{zones.public.name}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/private_zone_id_goes_here/#{zones.private.id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/private_zone_name_goes_here/#{zones.private.name}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s%api_server_name_goes_here%#{spec.huxley.url}%g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "sed \"s/cluster_id_goes_here/#{spec.cluster.id}/g\" < kick.cson > temp && " +
      "mv temp kick.cson && " +

      "cd /panda-kick/src/ && coffee --nodejs --harmony server.coffee\" \n" +
      "EOF"

    return change
