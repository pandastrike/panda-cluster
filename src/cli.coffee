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
{read, write, remove} = require "fairmont" # Awesome utility functions.
{parse} = require "c50n"                   # Awesome .cson file parsing
{pluck, where} = require "underscore"      # Awesome manipulations in the functional style.

PC = require "./pandacluster"             # Access PandaCluster!!


#===============================================================================
# Helper Fucntions
#===============================================================================
# Wrap parseInt - hardcode the radix at 10 to avoid confusion
# See: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/parseInt
is_integer = (value) -> parseInt(value, 10) != NaN

# Output an Info Blurb and optional message.
usage = (entry, message) ->
  if message?
    process.stderr.write "#{message}\n"

  throw read( resolve( __dirname, "..", "doc", entry ) )

# Accept only the allowed values for flags that take an enumerated type.
allow_only = (allowed_values, value, flag) ->
  if value not in allowed_values
    throw "\nError: Only Allowed Values May Be Specified For Flag: #{flag}\n\n"

# Accept only integers within the accepted range, inclusive.
allow_between = (min, max, value, flag) ->
  unless is_integer value
    throw "\nError: Value Must Be An Integer For Flag: #{flag}\n\n"

  unless min <= value <= max
    throw "\nError: Value Is Outside Allowed Range For Flag: #{flag}\n\n"

# Parse the arguments passed to a sub-command.  Construct an "options" object to pass to the main library.
parse_cli = (command, argv) ->
  # Deliver an info blurb if neccessary.
  usage command   if argv[0] == "-h" or argv[0] == "help"

  # Begin constructing the "options" object.
  options = {}

  # Extract flag data from the argument definition for this sub-command.
  definitions = parse( read( resolve(  __dirname, "argument_definitions.cson")))
  cmd_def = definitions[command]  # Produces an array of objects describing this single sub-command.
  flags = pluck cmd_def, "flag"
  required_flags = pluck( where( cmd_def, {required: true}), "flag" )

  # Loop over arguments.  Collect settings into "options" and validate where possible.
  while argv.length > 0
    # Check to see if the entered flag is valid.
    if flags.indexOf(argv[0]) == -1
      usage command, "\nError: Unrecognized Flag Provided: #{argv[0]}\n"
    # Check to see if there is a "dangling" flag that has no content provided.
    if argv.length == 1
      usage command, "\nError: Valid Flag Provided But Not Defined: #{argv[0]}\n"

    # Compare the argument its defintion.
    {name, type, required, allowed_values, min, max} = cmd_def[ flags.indexOf(argv[0]) ]

    allow_only( allowed_values, argv[1], argv[0])  if allowed_values?
    allow_between( min, max, argv[1], argv[0])     if min? and max?
    remove( required_flags, argv[0])               if required? == true

    # Add data to the "options" object.
    unless type?
      options[name] = argv[1]
    else if type == "object"
      options[name] = parse( read( argv[1]))

    # Delete these arguments.
    argv = argv[2..]

  # Done looping.  Check to see if all required flags have been defined.
  unless required_flags.length == 0
    usage command, "\nError: Mandatory Flag(s) Remain Undefined: #{required_flags}\n"

  # Parsing complete. Return the completed "options" object.
  return options


#===============================================================================
# Main - Top-Level Command-Line Interface
#===============================================================================
# Chop off the argument array so that only the useful arguments remain.
argv = argv[2..]

# Deliver an info blurb if neccessary.
if argv.length == 0 or argv[0] == "-h" or argv[0] == "help"
  usage "main"

# Grab credentials for the AWS account from the PandaCluster dotfile.
credentials = parse( read( resolve("#{process.env.HOME}/.pandacluster.cson"))).aws

# Now, look for the specified sub-command.
switch argv[0]
  when "build-template"
    options = parse_cli "build_template", argv[1..]
    PC.build_template options
  when "create"
    options = parse_cli "create", argv[1..]
    PC.create credentials, options
  when "destroy"
    options = parse_cli "destroy", argv[1..]
    PC.destroy credentials, options
  else
    # When the command cannot be identified, display the help guide.
    usage "main", "\nError: Command Not Found: #{argv[0]} \n"
