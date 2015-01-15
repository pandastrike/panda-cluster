type = (name) ->
  "application/vnd.trivial.#{name}+json;version=1.0"

module.exports =

  clusters:
    actions:
      create:
        method: "POST"
        request:
          type: type "cluster"
        response:
          type: type "cluster"
          status: 201
      destroy:
        method: "POST"
        request:
          type: type "cluster"
        response:
          type: type "cluster"
          status: 200

  users:
    actions:
      create:
        method: "POST"
        request:
          type: type "user"
        response:
          type: type "user"
          status: 201
      delete:
        method: "POST"
        request:
          type: type "user"
        response:
          type: type "user"
          status: 200

  user:
    actions:
      get:
        method: "GET"
        request:
          type: type "user"
        response:
          type: type "user"
          status: 200
