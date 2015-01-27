{merge} = require "fairmont"

blank =
  mappings: {}
  resources: {}
  schema: { definitions: {}}

collection = (name) ->
  "#{name}_collection"

class Builder

  constructor: (@name, @api = blank) ->

  define: (name, {path, template}={}) ->
    if path?
      @map name, {path}
    else
      template ?= "/#{name}/:key"
      @map name, {template}
    @_schema(name).mediaType = "application/vnd.#{@name}.#{name}+json"
    proxy =
      get: => @get name; proxy
      put: => @put name; proxy
      delete: => @delete name; proxy
      create: ({parent}) =>
        parent ?= collection name
        @map parent, path: "/#{parent}"
        @create name, parent
        proxy

  map: (name, spec) ->

    @api.mappings[name] ?= merge spec,
      resource: name
    @

  _actions: (name) ->
    resource = @api.resources[name] ?= {}
    resource.actions ?= {}

  _schema: (name) ->
    schema = @api.schema.definitions[name] ?= {}

  get: (name, {type, description}={}) ->
    type ?= "application/vnd.#{@name}.#{name}+json"

    description ?= if @api.mappings[name].template?
      "Returns a #{name} resource with the given key"
    else
      "Returns the #{name} resource"

    @_actions(name).get =
      description: description
      method: "GET"
      response:
        type: type
        status: 200
    @

  put: (name) ->
    @_actions(name).put =
      description: "Updates a #{name} resource with the given key"
      method: "PUT"
      request: type: "application/vnd.#{@name}.#{name}+json"
      response: status: 200
    @

  delete: (name) ->
    @_actions(name).delete =
      description: "Deletes a #{name} resource with the given key"
      method: "DELETE"
      response: status: 200
    @

  create: (name, parent) ->
    @_actions(parent).create =
      description: "Creates a #{name} resource whose
        URL will be returned in the location header"
      method: "POST"
      request: type: "application/vnd.#{@name}.#{name}+json"
      response: status: 201
    @

  reflect: ->
    @map "description", path: "/"
    @get "description",
      type: "application/json"
      description: "Returns a description of the API"

module.exports = Builder
