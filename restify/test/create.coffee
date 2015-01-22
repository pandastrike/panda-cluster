http = require "http"
assert = require "assert"

cson = require "c50n"
{read} = require "fairmont"
{resolve} = require "path"

querystring = require "querystring"

try
  aws = cson.parse (read(resolve("#{process.env.HOME}/.pandacluster.cson")))
catch error
  assert.fail error, null, "Credential file ~/.pandacluster.cson missing"

data = JSON.stringify aws

# data to be used in multiple requests

secret_token = null
cluster_name = "peter-cli-test"
cluster_url = null
email = "peterlongnguyen@gmail.com"

# create a user
console.log "******TEST: creating a user"

options =
  hostname: "127.0.0.1"
  port: 1337
  path: "/users"
  method: "POST"
  headers:
    "Content-Type": "application/x-www-form-urlencoded"
    "Content-Length": Buffer.byteLength(data)

req = http.request options, (res) ->
  console.log "STATUS: " + res.statusCode
  console.log "HEADERS: " + JSON.stringify(res.headers)
  res.setEncoding "utf8"
  res.on "data", (chunk) ->
    console.log "BODY: " + chunk
    response = JSON.parse chunk

    assert.equal response.email, email
    assert.ok response.secret_token
    secret_token = response.secret_token

    # create a cluster
    console.log "******TEST: creating a cluster"

    cluster_data =
      cluster_name: cluster_name
      secret_token: secret_token
      email: email

    cluster_data = JSON.stringify cluster_data

    options =
      hostname: "127.0.0.1"
      port: 1337
      path: "/clusters"
      method: "POST"
      headers:
        "Content-Type": "application/x-www-form-urlencoded"
        "Content-Length": Buffer.byteLength(cluster_data)

    req = http.request options, (res) ->
      console.log "STATUS: " + res.statusCode
      console.log "HEADERS: " + JSON.stringify(res.headers)
      res.setEncoding "utf8"
      res.on "data", (chunk) ->
        console.log "BODY: " + chunk
        response = JSON.parse chunk

        cluster_url = response.cluster_url
        assert.ok cluster_url

        # destroy a cluster
        console.log "*****TEST: destroying a cluster"

        cluster_data =
          secret_token: secret_token
          email: email

        cluster_data = JSON.stringify cluster_data

        options =
          hostname: "127.0.0.1"
          port: 1337
          path: "/cluster/#{cluster_url}"
          method: "POST"
          headers:
            "Content-Type": "application/x-www-form-urlencoded"
            "Content-Length": Buffer.byteLength(cluster_data)

        req = http.request options, (res) ->
          console.log "STATUS: " + res.statusCode
          console.log "HEADERS: " + JSON.stringify(res.headers)
          res.setEncoding "utf8"
          res.on "data", (chunk) ->
            console.log "BODY: " + chunk
            response = JSON.parse chunk

        req.on "error", (e) ->
          console.log "problem with request: " + e.message
          return

        req.write cluster_data
        req.end()




    # event error for create cluster
    req.on "error", (e) ->
      console.log "problem with request: " + e.message
      return

    req.write cluster_data
    req.end()



# event error for create user
req.on "error", (e) ->
  console.log "problem with request: " + e.message
  return

# write data to request body
req.write data
req.end()
