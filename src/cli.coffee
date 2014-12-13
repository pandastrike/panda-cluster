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

PC = require "./pandacluster"              # Access PandaCluster!!



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

#===============================================================================
# Parsing Functions
#===============================================================================
# Define parsing functions for each sub-command's arguments.

# Create
parse_create_arguments = (argv) ->
  # Deliver an info blurb if neccessary.
  if argv.length == 1 or argv[1] == "-h" or argv[1] == "help"
    usage "create"
    process.exit -1

  # Begin buliding the "options" object.
  options = {}

  # Establish an array of flags that *must* be found for this method to succeed.
  required_flags = ["-k", "-n"]

  # Loop over arguments.  To preserve the argv array, we create a temporary copy first.
  foo = argv[1..]

  while foo.length > 0
    if foo.length == 1
      usage "create", "\nError: Flag Provided But Not Defined: #{foo[0]}\n"
      process.exit -1

    switch foo[0]
      when "-i"
        options.instance_type = foo[1]
      when "-k"
        options.key_pair = foo[1]
        remove required_flags, "-k"
      when "-m"
        options.extra_space = foo[1]
      when "-n"
        options.stack_name = foo[1]
        remove required_flags, "-n"
      when "-s"
        options.cluster_size = foo[1]
      when "-t"
        options.template_path = foo[1]
      when "-u"
        options.public_keys = parse( read( resolve( foo[1] )))
      else
        usage "create", "\nError: Unrecognized Flag Provided: #{foo[0]}\n"
        process.exit -1

    foo = foo[2..]

  # Done looping.  Check to see if all required flags have been defined.
  if required_flags.length != 0
    usage "create", "\nError: Mandatory Flag(s) Remain Undefined: #{required_flags}\n"
    process.exit -1

  # After successful parsing, return the completed "options" object.
  return options

# Customize-Template
parse_customize_template_arguments = (argv) ->
  # Deliver an info blurb if neccessary.
  if argv.length == 1 or argv[1] == "-h" or argv[1] == "help" or argv.length > 2
    usage "customize_template"
    process.exit -1

  # Begin buliding the "options" object.
  options = {}

  # Establish an array of flags that *must* be found for this method to succeed.
  required_flags = ["-f"]

  # Loop over arguments.  To preserve the argv array, we create a temporary copy first.
  foo = argv[1..]

  while foo.length > 0
    if foo.length == 1
      usage "create", "\nError: Flag Provided But Not Defined: #{foo[0]}\n"
      process.exit -1

    switch foo[0]
      when "-f"
        options. = foo[1]
        remove required_flags, "-f"
      when "-p"
        options.write_path = foo[1]
      else
        usage "create", "\nError: Unrecognized Flag Provided: #{foo[0]}\n"
        process.exit -1

    foo = foo[2..]

  # Done looping.  Check to see if all required flags have been defined.
  if required_flags.length != 0
    usage "create", "\nError: Mandatory Flag(s) Remain Undefined: #{required_flags}\n"
    process.exit -1

  # After successful parsing, return the completed "options" object.
  return options

# Destroy
parse_destroy_arguments = (argv) ->
  # Deliver an info blurb if neccessary.
  if argv.length == 1 or argv[1] == "-h" or argv[1] == "help" or argv.length > 2
    usage "destroy"
    process.exit -1

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
  process.exit -1

# Now, look for the specified sub-command.
switch argv[0]
  when "create"
    credentials = extract_credentials "#{process.env.HOME}/.pandacluster.cson"
    options = parse_create_arguments argv
    PC.create credentials, options
  when "customize-template"
    options = parse_customize_template_arguments argv
    PC.customize_template credentials, options
  when "destroy"
    credentials = extract_credentials "#{process.env.HOME}/.pandacluster.cson"
    options = parse_destroy_arguments argv
    PC.destroy credentials, options
  else
    # When the command cannot be identified, display the help guide.
    usage "main", "\nError: Command Not Found: #{argv[0]} \n"
