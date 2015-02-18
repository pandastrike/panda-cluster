JSCK = require("jsck").draft3

module.exports = (schema) ->
  if schema?
    validator = (new JSCK {properties: schema})
    (object) ->
      {valid} = validator.validate object
      valid
  else
    (object) -> !(object?)
