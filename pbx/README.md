# PBX

> **Warning** This is an experimental project.

PBX is a reimagining of [Patchboard][1] with the following design goals:

* Support for the Patchboard API description schema

* Modularization of the architecture

* Simplification of request classification

* Support for ES6 (mostly via generator/promise-based interfaces)

* Optimizations for common development scenarios

Although PBX is currently a single library, the idea is to package and release it as several standalone libraries that can interoperate. We want to empower developers to pick and choose the tools they want to use and to ultimately be able to create their our Patchboard-based solutions.

These components include:

* A validator that uses [JSCK][2] for JSON schema validation. Validators are used to validate API definitions, query parameters, and request and response bodies.

* A client that uses [Shred][3] to generate HTTP API clients based on the API definition.

* A builder for creating API definitions quickly, much like you can do with frameworks like [Restify][4] and [Express][5] (except the definitions are valid Patchboard API definitions and can be discovered/reflected upon).

* A classifier for determining the `(resource, action)` pair associated with a given request.

* A context object that provides a series of helper methods for dealing with requests and responses, leveraging the API definition to do so.

* A processor that provides a standard request handler for use with the [Node HTTP API][6].

* A collection of behaviors encapsulating common API scenarios, such as providing an HTTP interface to a storage backend.

[1]:https://github.com/patchboard
[2]:https://github.com/pandastrike/jsck
[3]:https://github.com/pandastrike/shred
[4]:http://mcavage.me/node-restify/
[5]:http://expressjs.com/
[6]:http://nodejs.org/docs/v0.11.13/api/http.html#http_http_createserver_requestlistener

## Example: A Simple Blog Engine

First, let's define our API:

```coffee
Builder = require "pbx/builder"
builder = new Builder "blogly"

builder.define "blog"
.create parent: "blogs"
.get()
.put()
.delete()

builder.define "post", template: "/blog/:blog/:post"
.create parent: "blog"
.get()
.put()
.delete()

builder.reflect()

module.exports = builder.api
```

This API allows to create blogs, view and update them, and delete them. We can also do the same for posts within a blog. We also added reflection to our API, which means the Patchboard API definition is available via a `GET` request to `/`.

For example, if we have a blog named `my-blog` and a post named `pbx-example`, the API above would allow us to read that post with the following `curl` command:

```
$ curl 'http://acmeblogging.com/blog/my-blog/pbx-example'
    -H'accept:application.vnd.post+json;version=1.0
```

Let's serve up the API using the Node HTTP `createServer` method:

```coffee
{call} = require "when/generator"
pbx = require "pbx"
api = require "./api"

call ->
  (require "http")
  .createServer yield (pbx api, (-> {}))
  .listen 8080
```

If we run this, we'll have an HTTP server for our API running on port `8080` on `localhost`. We can even use `curl` to get a description of the interface:

```
$ curl http://localhost:8080/ -H'accept: application/json'
```

Wait, though…this API doesn't actually _do_ anything. We haven't created any behaviors to bind it to. That's what's going on with the function we're passing into the `pbx` function, which returns an empty object literal: `(-> {})`.

The `pbx` function takes our API definition and an initializer function that returns a set of handlers for each action defined by the API.

> **Separation of Interface and Implementation** Defining the API _interface_ separate from the _implementation_ is different from most other HTTP libraries. One benefit of this separation is that we can generate our implementation based on the API, or even make it dynamic (say, using JavaScript proxies).

> These dynamic implementation patterns are called _behaviors_. Behaviors open up a variety of possibilities for implementations. In this example, we'll simply define explicit handler functions for each action. But behaviors make it possible to encapsulate an reuse common patters (like storing a resource in a database).

Let's define our initializer function, which will set up a connection to a database and then return the functions that use the connection for storing blogs and their associated posts.

First, we set everything up.

```coffee
async = (require "when/generator").lift
{call} = require "when/generator"
{Memory} = require "pirate"

make_key = -> (require "key-forge").randomKey 16, "base64url"
```

Our initializer function will return a promise&mdash;PBX supports either returning the handlers directly or returning a promise that resolves to the handlers&mdash;so we pull in some promise-related functions from the `when` promise library. We'll use `pirate` for storage. Finally, we'll use `key-forge` to generate guaranteed unique keys for our blogs. (In real life, we'd probably use something a bit more reader-friendly.)

Let's initialize our storage and define the initializer function we're going to return to `pbx`.

```coffee
adapter = Memory.Adapter.make()


module.exports = async ->

  blogs = yield adapter.collection "blogs"
```

We now have a collection named `blogs` to store everything in. All we have to do now is return the handlers object.

This is an object whose properties are objects that represent resources. Those objects in turn have properties that represent the actions each resource must implement.

Let's start with making it possible to create new blogs:

```coffee

  blogs:

    create: async ({respond, url, data}) ->
      key = make_key()
      yield blogs.put key, (yield data)
      respond 201, "", location: url "blog", {key}

```

Easy enough. We generate a key for the blog, store the blog, and respond with a `201`. Handler functions are provided with a context object that includes a variety of helpful functions. Here, we're using argument destructuring to get the `respond`, `url`, and `data` helpers. You can learn more about these in the [API docs](./docs/api.md).

Once we have a blog, we want to be able to post to it:

```coffee

  blog:

    # create post
    create: async ({respond, url, data,
      match: { path: { key}}}) ->
      blog = yield blogs.get key
      blog.posts ?= []
      index = blog.posts.length
      post = yield data
      post.index = index
      blog.posts.push post
      yield blogs.put key, blog
      respond 201, "",
      location: (url "post", {key, index})
```

And, of course, we'd like to be able to get blogs and blog posts, update them, and possibly delete them:

```coffee
    get: async ({respond, match: {path: {key}}}) ->
      blog = yield blogs.get key
      respond 200, blog

    put: async ({respond, data,
                 match: {path: {key}}}) ->
      yield blogs.put key, (yield data)
      respond 200

    delete: async ({respond, match: {path: {key}}}) ->
      yield blogs.delete key
      respond 200

  post:

    get: async ({respond,
    match: {path: {key, index}}}) ->
      blog = yield blogs.get key
      post = blog.posts?[index]
      if post?
        context.respond 200, post
      else
        context.respond.not_found()

    put: async ({respond, data,
    match: {path: {key, index}}}) ->
      blog = yield blogs.get key
      post = blog.posts?[index]
      if post?
        blog.posts[index] = (yield data)
        respond 200
      else
        context.respond.not_found()

    delete: async ({respond,
    match: {path: {key, index}}}) ->
      blog = yield blogs.get key
      post = blog.posts?[index]
      if post?
        delete blog.posts[index]
        context.respond 200
      else
        context.respond.not_found()
```

We can now go back to our server and pass in our initializer function:

```coffee
{call} = require "when/generator"
pbx = require "pbx"
initialize = require "./handlers"
api = require "./api"
api.base_url = "http://localhost:8080"

call ->
  (require "http")
  .createServer yield (pbx api, initialize)
  .listen 8080
```

We've added the `base_url` property to our API so that the `url` helper for the context can generate proper URLs for us. We'd normally get this value from a configuration file or environment variable.
