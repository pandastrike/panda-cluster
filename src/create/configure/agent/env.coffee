#===============================================================================
# panda-cluster - Kick Server Environment Variables
#===============================================================================
# The kick server needs to be fed a configuration, including the user's AWS
# credentials.  Because of their sensitive nature, we cannot store them within
# an image, only within a running contianer.

# Fortunately, ECS allows us to pass environment variables into the container
# directly.

module.exports = (spec) ->
  [
    name: "config"
    value: JSON.stringify spec
  ]
