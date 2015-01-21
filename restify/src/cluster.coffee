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


module.exports = class Cluster

  constructor: ({datastore}) ->
    @mongo = datastore

  destroy_cluster: async ({req}) ->
    request_data = @mongo.destroy_cluster req
    yield pandacluster.destroy request_data

  create_cluster: async ({req}) ->
    user = @mongo.create_cluster req
    console.log "*****create request data: ", user
    {cluster_name} = cson.parse req.body
    request_data =
      public_keys: user.public_keys
      key_pair: "peter"
      aws: user.aws
      stack_name: cluster_name
    yield pandacluster.create request_data

#  create_cluster: async ({req}) ->
#    {params} = req
#    {body} = params
#    console.log params
#    yield @mongo.usersate body
#    request_data = get_request_data aws: aws, cluster_name: cluster_name
#    yield pandacluster.create request_data

  # FIXME: async
  # FIXME: move to separate file "user.coffee"
  create_user: ({req}) ->
    new_user = @mongo.create_user req
    console.log "*****this new user: ", new_user
    new_user

  get_all_users: ->
    @mongo.get_all_users()



