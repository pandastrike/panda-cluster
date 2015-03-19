#===============================================================================
# Panda-Cluster - Command-Line Tool
#===============================================================================
# This file specifies the Command-Line Interface for panda-cluster.  We access
# panda-cluster functions, but we have to build the "options" object for each
# method by parsing command-line arguments.  The CLI assumes very little, so it
# has a very minimalist interface.
#===============================================================================
# Modules
#===============================================================================
# Core Libraries
{resolve} = require "path"

# PandaStrike Libraries
{call} = require "fairmont"

# Components
{usage, load, parse_cli} = require "./helpers"


#===============================================================================
# Main - Top-Level Command-Line Interface
#===============================================================================
call ->
  # Chop off the argument array so that only the useful arguments remain.
  argv = process.argv[2..]

  try
    # Deliver info blurb if neccessary.
    if argv.length == 0 || argv[0] == "-h" || argv[0] == "help" || argv[0] == "--help"
      yield usage "main"

    # Begin parsing.  Start by loading the argument definitions so we can start matching.
    definition = yield load __dirname, "arguments.cson"

    # Search the top-level commands
    if argv[0] of definition

      # Passed. Deliver an info blurb if neccessary.
      if argv.length == 1 || argv[1] == "-h" || argv[1] == "help" || argv[1] == "--help"
        yield usage "#{argv[0]}/main"

      # Match among the sub-commands.
      else if argv[1] of definition[argv[0]]

        # Passed.  Parse the sub-command arguments and contstruct the configuration object "options."
        cmd_def = definition[argv[0]][argv[1]]
        options = yield parse_cli "#{argv[0]}/#{argv[1]}", cmd_def, argv[2..]
        options.aws.region = options.region  if options.region?

        # Success. Feed "options" into the panda-cluster library method.
        PC = (require "../panda-cluster")(options.aws)
        yield PC["#{argv[1]}_#{argv[0]}"] options

      else
        # When the sub-command cannot be identified, display the help guide.
        yield usage "#{argv[0]}/main", "\n Error: Command Not Found: #{argv[1]} \n"

    else
      # When the top-level command cannot be identified, display the help guide.
      yield usage "main", "\nError: Command Not Found: #{argv[0]} \n"

  catch error
    console.log "Error: Unable to execute command. \n", error
