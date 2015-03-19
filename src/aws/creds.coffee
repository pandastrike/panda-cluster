#===============================================================================
# Panda-Cluster - Awesome Library to Manage CoreOS Clusters
#===============================================================================
# This is the main file for the panda-cluster library.  From here, you can see
# several functions below that modify the state of clusters running on your cloud
# platform.

module.exports =
  # Configure the AWS object for account access.
  set_aws_creds = (creds) ->
    try
      return {
        accessKeyId: creds.id
        secretAccessKey: creds.key
        region: creds.region
        sslEnabled: true
      }
    catch error
      throw build_error "Unable to configure AWS.config object", error
