assert = require "assert"
cson = require "c50n"
{call} = require "when/generator"
{read} = require "fairmont"
{resolve} = require "path"
pandacluster = require "../src/pandacluster"
nock = require "nock"

require 'shelljs/global'

# test run (can't *really* test in current form, writes to file)
#pandacluster.templatize "services/hook-server.template", "src/services/hook-server.service",
#  ssh_keys: "hello world"
#  after: config.after || "skydns.service"

try
  aws = cson.parse (read(resolve("#{process.env.HOME}/.pandacluster.cson")))
catch error
  assert.fail error, null, "Credential file ~/.pandacluster.cson  missing"

options =
  public_keys: aws.public_keys
  stack_name: "peter-cli-test"
  ephemeral_drive: "/dev/xvdb"
  key_pair: "peter"
  formation_units: [
    {
      name: "format-ephemeral.service"
      runtime: true
      command: "start",
    },
    {
      name: "var-lib-docker.mount"
      runtime: true
      command: "start"
    }
  ]
  aws: aws.aws

call ->

  try

#    nock.recorder.rec
#      dont_print: false
#      output_objects: true
#      persist: true

    res = yield pandacluster.create options
    {status, message, code, details} = res
    assert.equal status, "success"
    assert.equal message, "The requested cluster is online, configured, and ready."
    assert.equal error, null


  catch error
    assert.throws error, null, "Create cluster failed"
    console.log error

#  fixtures = nock.recorder.play()
#  console.log "fixtures : #{JSON.stringify(fixtures, undefined, 2)}"


#  try
#    res = yield pandacluster.destroy options
#    console.log res
#    {status, message, error, data} = res
#    assert.equal status, "in progress"
#    assert.equal message, "Cluster destruction in progress"
#    assert.equal error, null
#    assert.ok data.destroy_cluster.ResponseMetaData.RequestId
#
#  catch error
#    assert.fail error, null, "Destroy cluster failed"






#
#
# TODO: setup option to record or play, but lower priority
# decide whether we want to run real requests or not
#should_record = false
#argv = require('minimist')(process.argv.slice(2))
#if argv.record? is true
#  should_record = true
#
#nock.recorder.rec
#  dont_print: true
#  output_objects: true
#nock_calls = nock.recorder.play()
#{read_file, write_file} = require "./file-rw"
#
#assert true, read_file "./json/create-cluster/success.json"
#assert true, write_file "./json/create-cluster/success.json", nock_recording
#nock.load path