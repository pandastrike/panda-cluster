
architecture.md
api-guide.md
unit-guide.md

main.coffee (?)

# architecture
------------------
1. Executing `bin/pandacluster` begins the CLI `src/cli.coffee`.
2. `src/cli.coffee` parses command and arguments, validating them against `argument_definitions.cson`.
3. `src/cli.coffee` is also hard-coded to read in the user's AWS credentials from `~/.pandacluster.cson`.
3. `src/cli.coffee` passes the arguments and AWS credentials to `src/pandacluster.coffee`.
4. `src/pandacluster.coffee` will fulfill the user command by either making a call to AWS API or pull CoreOS CloudFormation templates, using the URLs stored in `src/templates.cson`.


## bin
------------------

1. pandacluster
  - Wraps "src/cli.coffee" as an executable bash script to run the CLI.

##  doc
------------------

Contains the --help text provided for the CLI commands as used by `src/cli.coffee`.

1. create
2. destroy
3. main

## src
------------------

1. argument_definitions.cson
2. cli.coffee
3. pandacluster.coffee
4. templates.cson

## test
------------------

1. create_cluster.coffee
2. file_rw.coffee

### test/json
------------------

1. create-cluster
2. destroy-cluster

## units
------------------

Sample files for CoreOS systemd configuration.  The `build_template` method in `src/pandacluster.coffee` takes in a `units` .cson filepath option that references .service files.  These systemd unit files with .service extensions run cron-like processes.


1. unit-config.cson
  - # TODO
2. docker-tcp.service
  - Exposes Docker by specifying on which socket Docker should listen to.  Does not actually run.
4. enable-docker-tcp.service
  - Runs the docker-tcp.service.
4. format-ephemeral.service
  - Prepares the ephemeral drive for mounting by wiping the volume with wipefs and then formatting with mkfs.btrfs.
5. var-lib-docker.mount
  - Mounts the formatted ephemeral drive to /var/lib/docker.mount
