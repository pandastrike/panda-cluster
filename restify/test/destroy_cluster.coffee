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

secret_token = "blah"
email = "peterlongnguyen@gmail.com"
cluster_url = "123"


# destroy a cluster

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
