#===============================================================================
# Panda-Cluster - Generic Helpers
#===============================================================================
# This file specifies sundry helper functions that get reused throughout the codebase.

#----------------------
# Modules
#----------------------
node_lift = (require "when/node").lift


#----------------------
# Exposed Methods
#----------------------
modules.export =
  # Build an error object to let the user know something went worng.
  build_error = (message, details) ->
    error = new Error message
    error.details = details    if details?
    return error

  # Create a success object that reports data to user.
  build_success = (message, data) ->
    return {
      message: message
      status: "success"
      details: data       if data?
    }


  # Allow "when" to lift AWS module functions, which are non-standard.
  lift_object = (object, method) ->
    node_lift method.bind object

  # Enforces "fully qualified" form of hostnames and domains.  Idompotent.
  fully_qualified = (name) ->
    if name[name.length - 1] == "."
      return name
    else
      return name + "."

  # Render underscores and dashes as whitespace.
  plain_text = (string) ->
    string
    .replace( /_+/g, " " )
    .replace( /\W+/g, " " )


  # Create a list of objects, where the new objects are a subset of their original input.  "key" is
  # a simple string naming the target objects's *key* (cannot filter based on *value*).
  # "new_key" is optional and allows the objects to use a new string for its keys.
  subset = (map_list, key, new_key) ->
    result = []
    values = pluck(map_list, key)
    new_key ||= key

    for value in values
      temp = {}
      temp[new_key] = value
      result.push temp

    return result


  # Continue calling the async function until truthy value is returned.
  # Takes optional maximum iterations before continuing.
  poll_until_true = async (func, options, creds, duration, message, max) ->
    try
      # Initialize counter if we have a maximum.
      count = 0  if max?
      while true
        # Poll the function.
        status = yield func options, creds
        if status
          return status         # Complete.
        else
          yield pause duration  # Not complete. Keep going.

        # Iterate the counter
        count++ if max?
        return "WARNING: Max iterations reached.  Continuing Setup Anyway."  if count? > max?

    catch error
      return build_error message, error
