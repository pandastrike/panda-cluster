module.exports =

  mappings:
    blog:
      template: "/blog/:key"
      resource: "blog"

    post:
      template: "/post/:key"
      resource: "post"

  resources:
    blog:
      actions:
        get:
          description: "Returns a blog resource with the given key"
          method: "GET"
          response:
            type: "application/vnd.test.blog+json"
            status: 200

        create:
          description: "Creates a post resource whose URL will be returned in the location header"
          method: "POST"
          request:
            type: "application/vnd.test.post+json"

          response:
            status: 201

    post:
      actions:
        get:
          description: "Returns a post resource with the given key"
          method: "GET"
          response:
            type: "application/vnd.test.post+json"
            status: 200

        put:
          description: "Updates a post resource with the given key"
          method: "PUT"
          request:
            type: "application/vnd.test.post+json"
          response:
            status: 200

        delete:
          description: "Deletes a post resource with the given key"
          method: "DELETE"
          response:
            status: 200

  schema:

    definitions:
      blog:
        mediaType: "application/vnd.test.blog+json"

      post:
        mediaType: "application/vnd.test.post+json"
