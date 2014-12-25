{readFile, writeFile} = (liftAll require "fs")

read_file = (path) ->
  try
    yield readFile path
    true
  catch error
    console.log "Error writing #{path}: #{error}"
    false

write_file = (path, data) ->
  try
    yield writeFile path, data
    true
  catch error
    console.log "Error writing #{path}: #{error}"
    false
