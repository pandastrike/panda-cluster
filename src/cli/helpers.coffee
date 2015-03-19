#===============================================================================
# Panda-Cluster - CLI Helpers
#===============================================================================
{resolve} = require "path"
{async, call, read, write, compose} = require "fairmont"
{project, collect, has, deep_equal, remove} = require "fairmont"
{parse} = require "c50n"


#------------------------------------
# Helpers
#------------------------------------
# Wrap parseInt - hardcode the radix at 10 to avoid confusion
# See: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/parseInt
is_integer = (value) -> parseInt(value, 10) != NaN

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

where = async (array, query) ->
  final = []

  for obj in array
    count = 0
    for key of query
      break unless yield has key, obj
      break unless yield deep_equal obj[key], query[key]
      count++

    final.push obj  if count == Object.keys(query).length

  return final




#-------------------------
# Exposed Methods
#-------------------------
# Read from CSON file.
load = compose parse, read, resolve

# Output an Info Blurb and optional message.
usage = async (entry, message) ->
  if message?
    throw "#{message}\n" + yield read( resolve( __dirname, "../..", "doc", entry ) )
  else
    throw yield read( resolve( __dirname, "../..", "doc", entry ) )

# Parse the arguments passed to a sub-command.  Construct an "options" object to pass to the main library.
parse_cli = async (help_path, cmd_def, argv) ->
  # Deliver an info blurb if neccessary.
  yield usage help_path   if argv.length == 0 || argv[0] == "-h" || argv[0] == "help" || argv[0] == "--help"

  # Begin constructing the "options" object by pulling stored configuration data.
  options = {}
  options.aws         = (yield load "#{process.env.HOME}/.panda-cluster.cson").aws
  options.public_keys = (yield load "#{process.env.HOME}/.panda-cluster.cson").public_keys

  # Extract flag data from the argument definition for this sub-command.
  flags = collect yield project "flag", cmd_def
  long_flags = collect yield project "long_flag", cmd_def
  required_flags = collect yield project "flag", (yield where cmd_def, {required: true})
  required_long_flags = collect yield project "long_flag", (yield where cmd_def, {required: true})

  # Loop over arguments.  Collect settings into "options" and validate where possible.
  while argv.length > 0
    # Check to see if the entered flag is valid.
    unless argv[0] in flags || argv[0] in long_flags
      yield usage help_path, "\nError: Unrecognized Flag Provided: #{argv[0]}\n"
    # Check to see if there is a "dangling" flag that has no content provided.
    if argv.length == 1
      yield usage help_path, "\nError: Valid Flag Provided But Not Defined: #{argv[0]}\n"


    # Validate the argument against its defintion.  Identify the flag.
    if argv[0] in flags
      command = yield where cmd_def, {flag: argv[0]}
    else
      command = yield where cmd_def, {long_flag: argv[0]}

    # Pull its specification.
    {name, type, required, allowed_values, min, max} = command[0]

    # Remove flags from check-list if required.
    if required? == true
      remove required_flags, command[0].flag
      remove required_long_flags, command[0].long_flag

    allow_only( allowed_values, argv[1], argv[0])            if allowed_values?
    allow_between( min, max, argv[1], argv[0])               if min? and max?

    # Add data to the "options" object.
    if type? == "json"
      options[name] = JSON.parse argv[1]
    else
      options[name] = argv[1]

    # Delete these two arguments.
    argv = argv[2..]

  # Done looping.  Check to see if all required flags have been defined.
  unless required_flags.length == 0
    yield usage help_path, "\nError: Mandatory Flag(s) Remain Undefined: #{required_flags}\n"

  # Parsing complete. Return the completed "options" object.
  return options

# Declare exposed methods.
module.exports = {load, usage, parse_cli}
