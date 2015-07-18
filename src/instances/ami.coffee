# This file holds the AMI ID for a given AWS region.

module.exports =

  get: (region) ->
    switch region
      when "us-west-2" then "ami-d75350e7"
      else
        throw new Error "Unknown regions specifed."
