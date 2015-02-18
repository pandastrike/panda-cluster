{call} = require "when/generator"
{discover} = require "../../src/client"
amen = require "amen"
assert = require "assert"

amen.describe "Example blogging API", (context) ->

  context.test "Create a blog", (context) ->

    api = yield discover "http://localhost:8080"

    {response: {headers: {location}}} =
      (yield api.blogs.create title: "My Blog")

    blog = (api.blog location)

    context.test "Create a post", ->

      {response: {headers: {locations}}} =
        (yield blog.create
          title: "My First Post"
          content: "This is my very first post.")

      posts = (api.post location)

    context.test "Get a blog", ->

      {data} = yield blog.get()
      {posts} = yield data
      assert.equal posts.length, 1
