#===============================================================================
# PandaCluster - Awesome Command-Line Tool and Library to Manage CoreOS Clusters
#===============================================================================
# This file specifies the Command-Line Interface for PandaCluster.  When used as
# a command-line tool, we still call PandaCluster functions, but we have to build
# the "options" object for each method by parsing command-line arguments.

#===============================================================================
# Modules
#===============================================================================
{argv} = process
{resolve} = require "path"
{read, write, remove} = require "fairmont" # Easy file read/write
{parse} = require "c50n"                   # .cson file parsing

PC = require "./pandacluster-es6"          # Access PandaCluster!!



#===============================================================================
# Helper Fucntions
#===============================================================================
# Output an Info Blurb and optional message.
usage = (entry, message) ->
  if message?
    process.stderr.write "#{message}\n"

  process.stderr.write( read( resolve( __dirname, "..", "doc", entry ) ) )
  process.exit -1


# Extract AWS credientials from the PandaCluster dotfile.
extract_credentials = (path) ->
  credentials = parse( read( resolve( path )))
  return credentials.aws

# Accept only the allowed values for flags that take an enumerated type.
allow_only = (allowed_values, value, flag) ->
  if allowed_values.indexOf(value) == -1
    process.stderr.write "\nError: Only Allowed Values May Be Specified For Flag: #{flag}\n\n"
    process.exit -1

# Accept only integers within the accepted range, inclusive.
allow_between = (allowed_min, allowed_max, value, flag) ->
  if parseInt(value, 10) == NaN
    process.stderr.write "\nError: Value Must Be An Integer For Flag: #{flag}\n\n"
    process.exit -1

  if value < allowed_min or value > allowed_max
    process.stderr.write "\nError: Value Is Outside Allowed Range For Flag: #{flag}\n\n"
    process.exit -1



#===============================================================================
# Parsing Functions
#===============================================================================
# Define parsing functions for each sub-command's arguments.

#------------------------
# Build-Template
#------------------------
parse_build_template_arguments = (argv) ->
  # Deliver an info blurb if neccessary.
  if argv[1] == "-h" or argv[1] == "help" or argv.length > 2
    usage "build_template"

  # Begin buliding the "options" object.
  options = {}

  # Loop over arguments.  Collect settings and validate where possible.
  argv = argv[1..]

  while argv.length > 0
    if argv.length == 1
      usage "build_template", "\nError: Flag Provided But Not Defined: #{argv[0]}\n"

    switch argv[0]
      when "-c"
        allow_only ["pv", "hvm"], argv[1], argv[0]
        options.channel = argv[1]
      when "-p"
        options.write_path = argv[1]
      when "-u"
        options.units = parse( read( argv[1]))
      when "-v"
        allow_only ["alpha", "beta", "stable"], argv[1], argv[0]
        options.virtualization = argv[1]
      else
        usage "build_template", "\nError: Unrecognized Flag Provided: #{argv[0]}\n"

    argv = argv[2..]

  # Parsing complete.  As referenced in the docs, failure to provide a template
  # "write_path" results in PandaCluster defaulting to the working directory.
  unless options.write_path?
    options.write_path = "template.json"

  # Return the completed "options" object.
  return options


#------------------------
# Create
#------------------------
parse_create_arguments = (argv) ->
  # Deliver an info blurb if neccessary.
  if argv.length == 1 or argv[1] == "-h" or argv[1] == "help"
    usage "create"

  # Begin buliding the "options" object.
  options = {}

  # Establish an array of flags that *must* be found for this method to succeed.
  required_flags = ["-k", "-n"]

  # Loop over arguments.  Collect settings and validate where possible.
  argv = argv[1..]

  while argv.length > 0
    if argv.length == 1
      usage "create", "\nError: Flag Provided But Not Defined: #{argv[0]}\n"

    switch argv[0]
      when "-i"
        allowed_values = [ "c1.medium", "c1.xlarge", "c3.large", "c3.xlarge",
        "c3.2xlarge", "c3.4xlarge", "c3.8xlarge", "hi1.4xlarge", "hs1.8xlarge",
        "m1.medium", "m1.large", "m1.xlarge", "m2.xlarge", "m2.2xlarge", "m2.4xlarge",
        "m3.medium", "m3.large", "m3.xlarge", "m3.2xlarge", "t1.micro"]

        allow_only allowed_values, argv[1], argv[0]
        options.instance_type = argv[1]
      when "-k"
        options.key_pair = argv[1]
        remove required_flags, "-k"
      when "-n"
        options.stack_name = argv[1]
        remove required_flags, "-n"
      when "-r"
        allowed_values = ["ap-northeast-1", "ap-southeast-1", "ap-southeast-2",
        "eu-central-1", "eu-west-1", "sa-east-1", "us-east-1", "us-west-1",
        "us-west-2"]

        allow_only allowed_values, argv[1], argv[0]
        options.region = argv[1]
      when "-s"
        allow_between 3, 12, argv[1], argv[0]
        options.cluster_size = parseInt argv[1], 10
      when "-t"
        options.template_path = argv[1]
      else
        usage "create", "\nError: Unrecognized Flag Provided: #{argv[0]}\n"

    argv = argv[2..]

  # Done looping.  Check to see if all required flags have been defined.
  if required_flags.length != 0
    usage "create", "\nError: Mandatory Flag(s) Remain Undefined: #{required_flags}\n"

  # After successful parsing, return the completed "options" object.
  return options

#------------------------
# Destroy
#------------------------
parse_destroy_arguments = (argv) ->
  # Deliver an info blurb if neccessary.
  if argv.length == 1 or argv[1] == "-h" or argv[1] == "help" or argv.length > 2
    usage "destroy"

  # Build the "options" object.
  options = {}
  options.stack_name = argv[1]

  # After successful parsing, return the completed "options" object.
  return options



#===============================================================================
# Top-Level Command-Line Parsing
#===============================================================================
# Chop off the argument array so that only the arguments remain.
argv = argv[2..]

# Deliver an info blurb if neccessary.
if argv.length == 0 or argv[0] == "-h" or argv[0] == "help"
  usage "main"

# Now, look for the specified sub-command.
switch argv[0]
  when "build-template"
    options = parse_build_template_arguments argv
    PC.build_template options
  when "create"
    credentials = extract_credentials "#{process.env.HOME}/.pandacluster.cson"
    options = parse_create_arguments argv
    PC.create credentials, options
  when "destroy"
    credentials = extract_credentials "#{process.env.HOME}/.pandacluster.cson"
    options = parse_destroy_arguments argv
    PC.destroy credentials, options
  else
    # When the command cannot be identified, display the help guide.
    usage "main", "\nError: Command Not Found: #{argv[0]} \n"
