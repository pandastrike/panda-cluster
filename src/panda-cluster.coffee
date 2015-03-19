#===============================================================================
# Panda-Cluster - Awesome Library to Manage CoreOS Clusters
#===============================================================================
# This is the main file for the panda-cluster library.  From here, you can see
# several functions below that modify the state of clusters running on your cloud
# platform.

{async} = require "fairmont"

{enforce_config_defaults} = require "./magic-numbers"
{build_error, build_success} = require './helpers'
{}


module.exports = (credentials) ->

  # Authorize access to the Amazon Web Services API.
  AWS = require "aws-sdk"
  AWS.config = (require "./creds").set_aws_creds credentials

  # Declare functions by passing in the AWS instance.
  {launch_stack, get_formation_status,
   get_cluster_vpc_id, get_cluster_subnet} = require("./aws/cloud-formation")(AWS)



  #------------------------
  # Exposed Methods
  #------------------------
  # This method creates and starts a CoreOS cluster.
  create_cluster: async (options) ->
    # Enforce configuration defaults
    {options} = enforce_config_defaults options, "create"

    try
      # Make calls to Amazon's API. Gather data as we go.
      data = {}
      data.launch_stack = yield launch_stack options
      console.log "Stack Launched.  Formation In-Progress."

      # # Monitor the CloudFormation stack until it is fully created.
      # data.detect_formation = yield poll_until_true get_formation_status, options,
      #  credentials, 5000, "Unable to detect cluster formation."
      # console.log "Stack Formation Complete."
      #
      # # Now that CloudFormation is complete, identify the VPC and subnet that were created.
      # options.vpc_id = yield get_cluster_vpc_id options, credentials
      # options.subnet_id = yield get_cluster_subnet options, credentials
      #
      # # If we're using spot instances, we'll need to wait and detect when our Spot Request has been fulfilled.
      # if options.spot_price?
      #   console.log "Waiting for Spot Instance Fulfillment."
      #   # Spot Instances - wait for our Spot Request to be fulfilled.
      #   {result, instances} = yield poll_until_true get_spot_status, options,
      #    credentials, 5000, "Unable to detect Spot Instance fulfillment."
      #
      #   data.detect_spot_fulfillment = result
      #   options.instances = instances
      #   console.log "Spot Request Fulfilled. Instance Online."
      # else
      #   # On-Demand Instances - already active from CloudFormation.
      #   options.instances = yield get_on_demand_instances options, credentials
      #   console.log "On-Demand Instance Online."
      #
      #
      # # Get the IP addresses of our instances.
      # console.log "Retrieving Primary Public and Private IP Addresses."
      # for i in [0..options.instances.length - 1]
      #   {id} = options.instances[i]
      #   {public_ip, private_ip} = yield get_ip_address(id, credentials)
      #   options.instances[i] =
      #     id: id
      #     public_ip: public_ip
      #     private_ip: [private_ip]
      #   console.log "Instance #{id}: #{public_ip} #{private_ip}"
      #
      # # Continue setting up the cluster.
      # data.customize_cluster = yield customize_cluster( options, credentials)
      #
      # console.log "Done. \n"
      # #console.log  JSON.stringify data, null, '\t'
      # return build_success "The requested cluster is online, configured, and ready.",
      #   data


    catch error
      console.log JSON.stringify error, null, '\t'
      return build_error "Apologies. The requested cluster cannot be created.", error


  # This method stops and deletes a CoreOS cluster.
  delete_cluster: async (options) ->
    # Enforce configuratio defaults
    {options, credentials} = enforce_config_defaults options

    try
      # Make calls to Amazon's API. Gather data as we go.
      data = {}

      # Before we delete the stack, we must identify other resources associated with the cluster.
      # We can use the the ID of the VPC where the cluster resides.  Identify it.
      options.vpc_id = yield get_cluster_vpc_id options, credentials

      # Now delete the associated resources.
      data.delete_private_domain = yield delete_private_domain( options, credentials)

      # Delete the CloudFormation Stack running our cluster.
      data.delete_stack = yield delete_stack( options, credentials)

      console.log "Done. \n"
      return build_success "The targeted cluster has been destroyed.  All related resources have been released.",
      data

    catch error
      return build_error "Apologies. The targeted cluster has not been destroyed.", error

  get_cluster_status: async (options) ->
     # Enforce configuratio defaults
     {options, credentials} = enforce_config_defaults options

     yield get_formation_status options, credentials
