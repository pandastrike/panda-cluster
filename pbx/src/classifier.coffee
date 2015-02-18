validator = require "./validator"
errors = require "./errors"

# TODO: make this more sophisticated
acceptable = (header, definition) ->
  header == "*/*" || header == definition

module.exports = (api) ->

  router = do (require "routington")

  for rname, resource of api.resources
    {path, template, query} = api.mappings[rname]
    path ?= template
    [node] = router.define path
    node.resource =
      name: rname
      actions: {}
      query: {validate: (validator query)}
    for aname, action of resource.actions
      node.resource.actions[action.method.toUpperCase()] = action
      action.name = aname
  url = require "url"

  (request) ->
    {pathname, query} = (url.parse request.url, true)
    path = pathname
    if (route = router.match path)?
      {node: {resource}, param} = route
      if (resource.query.validate query)
        match = { resource, path: param, query }
        if (match.action = resource?.actions?[request.method])?
          if (acceptable request.headers.accept, match.action.response?.type)
            if request.headers["content-type"] == match.action.request?.type
              match
            else
              throw errors.unsupported_media_type()
          else
            throw errors.not_acceptable()
        else
          throw errors.method_not_allowed()
      else
        throw errors.not_found()
    else
      throw errors.not_found()
