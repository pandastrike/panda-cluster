#===============================================================================
# PandaCluster - Awesome Command-Line Tool and Library to Manage CoreOS Clusters
#===============================================================================

#====================
# Modules
#====================
{argv} = process
{resolve} = require "path"
{read, write} = require "fairmont" # Easy file read/write
{parse} = require "c50n"           # .cson file parsing
{exec} = require "shelljs"         # Access to commandline
aws = require "aws-sdk"            # Access AWS API


#====================
# Helper Fucntions
#====================
# Output an Info Blurb and optional message.
usage = (entry, message) ->
  if message?
    process.stderr.write "#{message}\n"

  process.stderr.write( read( resolve( __dirname, "..", "doc", entry ) ) )
  process.exit -1


# Extract any configuration settings from the PandaCluster dotfile.
extractConfig = (path) ->
  return config = parse( read( resolve( process.env.HOME, ".pandacluster.cson")))

#===============================
# Module Definition
#===============================
module.exports =
  # This method creates and starts a CoreOS cluster.
  create: (credentials, clusterName, clusterSize, machineType) ->

  template = '{
    "AWSTemplateFormatVersion" : "2010-09-09"
    }'

  # This method stops and destroys a CoreOS cluster.
  destroy: (credentials, clusterName) ->


#===============================
# Command-Line
#===============================
# When PandaCluster is used as a commnad-line tool, this section is used to call
# module functions with command-line arguments.

# Chop off the argument array so that only the arguments remain.
argv = argv.slice 2

# Check the command arguments.  Deliver an info blurb if neccessary.
if argv.length == 0 or argv[2] == "-h" or argv[2] == "help"
  usage "main"
  process.exit -1

# Now, look for the top-level commands.
switch argv[2]
  when "create"
    a = 1
    module.exports.create argv
  when "destroy"
    a = 1
    module.exports.destroy argv
  else
    # When the command cannot be identified, display the help guide.
    usage "main", "\nError: Command Not Found: #{argv[2]} \n"
