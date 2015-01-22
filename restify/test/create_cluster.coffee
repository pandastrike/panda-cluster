
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

secret_token = "123"
cluster_name = "peter-cli-test"
cluster_url = "123"
email = "peterlongnguyen@gmail.com"

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

# event error for create cluster
req.on "error", (e) ->
  console.log "problem with request: " + e.message
  return

req.write cluster_data
req.end()

