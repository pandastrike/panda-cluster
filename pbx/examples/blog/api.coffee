Builder = require "../../src/builder"
builder = new Builder "test"


builder.define "cluster", template: "/cluster/:cluster_url"
.create parent: "clusters"
#.get()
#.put()
.delete()

builder.define "clusters"
.get()

builder.define "users"
.create parent: "users"
.get()
#.put()
#.delete()

builder.define "user", template: "/users/:email"
.create parent: "users"
.get()


#builder.define "blog"
#.create parent: "blogs"
#.get()
#.put()
#.delete()
#
#builder.define "post", template: "/blog/:key/:index"
#.create parent: "blog"
#.get()
#.put()
#.delete()

builder.reflect()

module.exports = builder.api
console.log builder.api

