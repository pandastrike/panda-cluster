Client = require("patchboard-js")

api = require "./api"

class GitHubClient extends Client
  constructor: (login, password) ->
    @basic_auth_string = new Buffer("#{login}:#{password}").toString("base64")
    super api,
      authorizer: (type, action) =>
        resource = @
        if type == "Basic"
          @basic_auth_string
        else
          throw "Can't supply credential for #{type}"

  identifiers:
    user: (object) ->
      {login: object.login}

    organization: (object) ->
      {login: object.login}

    repository: (object) ->
      {login: object.login || object.owner.login, name: object.name}




module.exports = GitHubClient

