# Helpers for Huxley cluster launch method.
{async, cat, collect, project, map, sleep} = require "fairmont"
{demand, spot, confirm} = require "../../instances"

module.exports =
  # Validate the SSH key name submitted to Huxley.  We cannot form a cluster
  # without a key that is known to the user's AWS account.
  validate: async (key, aws) ->
    {KeyPairs} = yield aws.ec2.describe_key_pairs {}
    names = collect project "KeyName", KeyPairs
    if key in names
      return true # Validated
    else
      throw new Error "This AWS account does not have a key pair named " +
        \"#{key_name}\"."

  # We must wait until all cluster resources are online and ready.
  wait: async (spec, aws) ->
    # Start with the Spot Requests.  Once they have been fulfilled, we get instance
    # IDs and can confirm all are online.
    for id, group of spec.cluster.resources when group.class == "EC2 spot request"
      spec = yield spot.confirm id, spec, aws

    # Now, confirm that all instances have completed their boot instructions.
    ids = []
    ids = cat ids, (collect project "id", group.instances) for id, group of spec.cluster.resources
    params = InstanceIds: ids

    is_active = (x) -> x == "running"
    is_failed = (x) -> x == "shutting-down" || x == "terminated" || x == "stopping" || x == "stopped"

    while true
      {Reservations} = aws.describe_instances params
      groups = collect project "Instances", Reservations
      states = cat instances, (collect project "State", group) for group in groups
      success = collect map is_active, states
      failure = collect map is_failed, states

      if true in failure
        throw new Error "There was a problem during instance spinup."
      else if false !in success
        # All instances are online and ready to recieve instructions.
        # Gather all instance IDs and IP addresses.  Add them to the "resources" object.
        ids = cat instances, (collect project "InstanceId", group) for group in groups
        public_ips = cat instances, (collect project "PublicIpAddress", group) for group in groups
        private_ips = cat instances, (collect project "PrivateIpAddress", group) for group in groups
        blob = {}
        for i in [0...ids.length]
          blob[ids[i]] =
            public: public_ips[i]
            private: private_ips[i]

        for key, group of spec.cluster.resources
          for i in [0...group.instances.length]
            {id} = group.instances[i]
            group.instances[i].ip = blob[id].ip

          spec.cluster.resources[key] = group


      else
        yield sleep 5000 # Request is pending.
