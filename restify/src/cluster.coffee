{lift} = require "when"
async = (require "when/generator").lift
pandacluster = require "../../src/pandacluster"

cson = require "c50n"
{read} = require "fairmont"
{resolve} = require "path"


# TODO: move to separate file
try
  aws = cson.parse (read(resolve("#{process.env.HOME}/.pandacluster.cson")))
catch error
  assert.fail error, null, "Credential file ~/.pandacluster.cson missing"

get_request_data = ({aws, cluster_name}) ->
  public_keys: aws.public_keys
  stack_name: cluster_name
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


module.exports =

  destroy_cluster: async ({cluster_name}) ->
    request_data = get_request_data aws: aws, cluster_name: cluster_name
    yield pandacluster.destroy request_data

  create_cluster: async ({cluster_name}) ->
    console.log "aws: ", aws
    request_data = get_request_data aws: aws, cluster_name: cluster_name
    yield pandacluster.create request_data
