module.exports =

  cluster:
    actions:
      create:
        method: "POST"
        request_schema: "cluster"
        status: 201
      destroy:
        method: "POST"
        request_schema: "cluster"
        status: 200
