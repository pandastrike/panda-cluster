{SchemaManager} = require("patchboard-js")
schema = require("./api/schema.coffee")
SchemaManager.normalize(schema)
#service_url = "https://api.github.com"
module.exports =
  service_url: service_url
  mappings: require("./api/directory")
  resources: require("./api/resources")
  schemas: [require("./api/schema")]
