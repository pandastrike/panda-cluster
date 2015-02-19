#===============================================================================
# panda-cluster - Awesome Command-Line Tool and Library to Manage CoreOS Clusters
#===============================================================================
# This file specifies the Command-Line Interface for panda-cluster.  When used as
# a command-line tool, we still call panda-cluster functions, but we have to build
# the "options" object for each method by parsing command-line arguments.

#===============================================================================
# Modules
#===============================================================================
{argv} = process
{resolve} = require "path"
{read, write, remove} = require "fairmont" # Awesome utility functions.
{parse} = require "c50n"                   # Awesome .cson file parsing

# Awesome manipulations in the functional style.
{pluck, where, flatten} = require "underscore"

# Access panda-cluster!!
PC = require "./panda-cluster"


#===============================================================================
# Helper Fucntions
#===============================================================================
# Wrap parseInt - hardcode the radix at 10 to avoid confusion
# See: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/parseInt
is_integer = (value) -> parseInt(value, 10) != NaN

# Output an Info Blurb and optional message.
usage = (entry, message) ->
  if message?
    throw "#{message}\n" + read( resolve( __dirname, "..", "doc", entry ) )
  else
    throw read( resolve( __dirname, "..", "doc", entry ) )

# Accept only the allowed values for flags that take an enumerated type.
allow_only = (allowed_values, value, flag) ->
  unless value in allowed_values
    throw "\nError: Only Allowed Values May Be Specified For Flag: #{flag}\n\n"

# Accept only integers within the accepted range, inclusive.
allow_between = (min, max, value, flag) ->
  unless is_integer value
    throw "\nError: Value Must Be An Integer For Flag: #{flag}\n\n"

  unless min <= value <= max
    throw "\nError: Value Is Outside Allowed Range For Flag: #{flag}\n\n"

# Parse the arguments passed to a sub-command.  Construct an "options" object to pass to the main library.
parse_cli = (help_path, cmd_def, argv) ->
  # Deliver an info blurb if neccessary.
  usage help_path   if argv[0] == "-h" || argv[0] == "help"

  # Begin constructing the "options" object by pulling stored configuration data.
  # (1) The "master" dotfile located in the $HOME directory.  Sensitive AWS credentials are stored there.
  # (2) A Huxley manifest file that allows the app to self-describe its deployment.

  # This particular command's needs are stored as meta-data in the command's description.
  {dotfile_master, manifest} = cmd_def[0]
  if manifest
    return options = parse( read( resolve( "#{process.cwd()}/huxley.cson")))
  else
    options = {}

  if dotfile_master
    options.aws         = parse( read( resolve("#{process.env.HOME}/.panda-cluster.cson"))).aws
    options.public_keys = parse( read( resolve("#{process.env.HOME}/.panda-cluster.cson"))).public_keys

  # Extract flag data from the argument definition for this sub-command.
  flags = pluck cmd_def, "flag"
  long_flags = pluck cmd_def, "long_flag"
  required_flags = pluck( where( cmd_def, {required: true}), "flag" )
  required_long_flags = pluck( where( cmd_def, {required: true}), "long_flag" )

  # Loop over arguments.  Collect settings into "options" and validate where possible.
  while argv.length > 0
    # Check to see if the entered flag is valid.
    unless argv[0] in flags || argv[0] in long_flags
      usage help_path, "\nError: Unrecognized Flag Provided: #{argv[0]}\n"
    # Check to see if there is a "dangling" flag that has no content provided.
    if argv.length == 1
      usage help_path, "\nError: Valid Flag Provided But Not Defined: #{argv[0]}\n"


    # Validate the argument against its defintion.  Identify the flag.
    if argv[0] in flags
      command = where cmd_def, {flag: argv[0]}
    else
      command = where cmd_def, {long_flag: argv[0]}

    # Pull its specification.
    {name, type, required, allowed_values, min, max} = command[0]

    # Remove flags from check-list if required.
    if required? == true
      remove required_flags, command[0].flag
      remove required_long_flags, command[0].long_flag

    allow_only( allowed_values, argv[1], argv[0])                     if allowed_values?
    allow_between( min, max, argv[1], argv[0])                        if min? and max?

    # Add data to the "options" object.
    if type? == "json"
      options[name] = argv[1]
    if type? == "boolean"
      options[name] = true
    else
      options[name] = argv[1]

    # Delete these two arguments.
    argv = argv[2..]

  # Done looping.  Check to see if all required flags have been defined.
  unless required_flags.length == 0
    usage help_path, "\nError: Mandatory Flag(s) Remain Undefined: #{required_flags}\n"

  # Parsing complete. Return the completed "options" object.
  return options


# If the user requests to mount additional drives for their Docker containers, they
# set the "-m" flag.  For now, we specify the default configurations to keep thing simple.
add_formation_units = (options) ->
  options.formation_service_templates =
    format_ephemeral: "default"
    var_lib_docker: "default"

  return options

#===============================================================================
# Main - Top-Level Command-Line Interface
#===============================================================================
# Chop off the argument array so that only the useful arguments remain.
argv = argv[2..]


if argv.length == 0 || argv[0] == "-h" || argv[0] == "help"
  usage "main"

# Begin parsing.  Start by loading the argument definitions so we can start matching.
definition = parse( read( resolve(  __dirname, "arguments.cson")))

# Search the top-level commands
if argv[0] of definition
  # Passed.  Now match among its sub-commands.

  if argv.length == 1 || argv[1] == "-h" || argv[1] == "help"
    # Deliver an info blurb if neccessary.
    usage "#{argv[0]}/main"
  else if argv[1] of definition[argv[0]]
    # Passed.  Now parse the sub-command arguments and contstruct the configuration object "options."
    cmd_def = definition[argv[0]][argv[1]]
    options = parse_cli "#{argv[0]}/#{argv[1]}", cmd_def, argv[2..]
    options = add_formation_units options     if options.formation_service_templates == "true"
    # Success. Launch the appropriate function.
    PC["#{argv[1]}_#{argv[0]}"] options
  else
    # When the sub-command cannot be identified, display the help guide.
    usage "#{argv[0]}/main", "\n Error: Command Not Found: #{argv[1]} \n"

else
  # When the top-level command cannot be identified, display the help guide.
  usage "main", "\nError: Command Not Found: #{argv[0]} \n"
