#===============================================================================
# panda-cluster - CloudFormation Template - Cloud Config Metadata
#===============================================================================
# It is possible to add ephemeral storage to each machine in the cluster and mount
# the Docker host to that drive before "Docker.service" starts.  The amount of
# additional storage you get depends on the EC2 instance you're using.  Look here for more...
# http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html

module.exports =
  format_ephemeral:
    filename: "format-ephemeral.service"
    runtime: "true"
    command: "start"

  var_lib_docker:
    filename: "var-lib-docker.mount"
    runtime: "true"
    command: "start"
