assert = require "assert"
{call} = require "when/generator"
#require "../src/cli"

require 'shelljs/global'

call ->

  try
    res = yield (exec './bin/pandacluster create -n peter-cli-test -k peter')
    console.log res

  catch error
    console.log error


#call ->
#
#  try
#    res = yield (exec './bin/pandacluster destroy -n peter-cli-test -k peter')
#    console.log res
#
#  catch error
#    console.log error
#
#
#call ->
#
#  try
#    res = yield (exec './bin/pandacluster build_template -n peter-cli-test -k peter')
#    console.log res
#
#  catch error
#    console.log error


    #call ->
#
#  try
#    console.log "foobar"
#    console.log "barfoo"
#
#    response = yield cli.parse_cli "create", ["-n", "peter-cli-test", "-k", "peter"]
#    console.log response
#    assert.equal 201, response.statusCode
#
#  catch error
#    console.error error






#assert = require "assert"
#nock = require "nock"
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
