Builder = require "../../src/builder"
builder = new Builder "test"


builder.define "cluster", template: "/cluster/:cluster_url"
.create parent: "clusters"
.get()
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


builder.reflect()

module.exports = builder.api
console.log builder.api

