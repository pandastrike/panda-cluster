assert = require "assert"
{call} = require "when/generator"
{resolve} = require "path"
{read} = require "fairmont"
pandacluster = require "../src/pandacluster"
cson = require "c50n"

require 'shelljs/global'


aws = cson.parse (read(resolve("#{process.env.HOME}/.pandacluster.cson")))
options =
  public_keys: aws.public_keys
  stack_name: "peter-cli-test"
  key_pair: "peter"
  units: []
  aws: aws.aws

call ->

  try
    res = yield pandacluster.create options
    console.log res

  catch error
    console.log error

  try
    #res = yield pandacluster.destroy options
    console.log res

  catch error
    console.log error






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
