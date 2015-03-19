#===============================================================================
# Panda-Cluster - Cloud Formation - Templates
#===============================================================================
# AWS CloudFormation relies on templates to describe instance deployments.  This
# file specifies those templates and the methods needed to construct them.

#----------------
# Modules
#----------------
{load} = require "../helpers"
{async, read} = require "fairmont"
{}

#---------------------
# Helpers
#---------------------
# Pulls the most recent AWS CloudFormation template from CoreOS.
pull_cloud_template = async ({channel, virtualization}) ->
  # This directory has a handy CSON file of URLs for CoreOS's latest CloudFormation templates.
  template_store = yield load __dirname, "..", "cloudformation-templates.cson"
  template_url = template_store[channel][virtualization]

  try
    response = yield https_get template_url
    template_object = JSON.parse (yield get_body response)
    return template_object

  catch error
    return build_error "Unable to access AWS template stores belonging to CoreOS", error


# Configure a Virtual Private Cloud (VPC) within this CloudFormation template.
configure_vpc = (template) ->
  # Isolate the "Resources" object within the JSON template object.
  resources = template.Resources

  # Add an object specifying a VPC.
  resources["VPC"] =
    Type: "AWS::EC2::VPC"
    Properties:
      CidrBlock: "10.0.0.0/16"
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags: [ {Key: "Name", Value: options.cluster_name} ]

  # Add an object specifying a subnet.
  resources["ClusterSubnet"] =
    Type: "AWS::EC2::Subnet"
    Properties:
      AvailabilityZone: options.availability_zone
      VpcId: { Ref: "VPC" }
      CidrBlock : "10.0.0.0/16"

  # Add an object specifying an Internet Gateway.
  resources["ClusterGateway"] =
    Type: "AWS::EC2::InternetGateway"
    Properties:
      Tags: [ {Key: "Name", Value: options.cluster_name} ]

  # Add an object specifying the attachment of this Internet Gateway.
  resources["AttachClusterGateway"] =
    Type: "AWS::EC2::VPCGatewayAttachment"
    Properties:
      InternetGatewayId: {Ref: "ClusterGateway"}
      VpcId: {Ref: "VPC"}

  # Add an object specifying the creation of a new Route Table.
  resources["ClusterRouteTable"] =
    Type: "AWS::EC2::RouteTable"
    Properties:
      VpcId: {Ref: "VPC"}
      Tags: [ {Key: "Name", Value: options.cluster_name} ]

  # Add an object specifying a Route for public addresses (through the Internet Gateway).
  resources["PublicRoute"] =
    Type: "AWS::EC2::Route"
    DependsOn: "ClusterGateway"
    Properties:
      DestinationCidrBlock: "0.0.0.0/0"
      GatewayId: {Ref: "ClusterGateway"}
      RouteTableId: {Ref: "ClusterRouteTable"}

  # Add an object associating the new Route Table with our VPC.
  resources["AttachRouteTable"] =
    Type: "AWS::EC2::SubnetRouteTableAssociation"
    Properties:
      RouteTableId: {Ref: "ClusterRouteTable"}
      SubnetId: {Ref: "ClusterSubnet"}

  # Return the augmented template object.
  template.Resources = resources
  return template

# Configure this deployment's AWS Security Group.
configure_security_group = (template) ->
  # Isolate the "Resources" object within the JSON template object.
  resources = template.Resources

  # Start by deleting the current configuration.  We need start over to accomodate the VPC.
  delete resources.CoreOSSecurityGroup
  delete resources.Ingress4001
  delete resources.Ingress7001

  # Expose the following ports...
  resources["ClusterSecurityGroup"] =
    Type: "AWS::EC2::SecurityGroup"
    Properties:
      GroupDescription: "PandaCluster SecurityGroup"
      VpcId: {Ref: "VPC"}
      SecurityGroupIngress: [
        { # SSH Exposed to the public Internet
          IpProtocol: "tcp"
          FromPort: "22"
          ToPort: "22"
          CidrIp: "0.0.0.0/0"
        }
        { # HTTP Exposed to the public Internet
          IpProtocol: "tcp"
          FromPort: "80"
          ToPort: "80"
          CidrIp: "0.0.0.0/0"
        }
        { # HTTPS Exposed to the public Internet
          IpProtocol: "tcp"
          FromPort: "443"
          ToPort: "443"
          CidrIp: "0.0.0.0/0"
        }
        { # Privileged ports exposed only to machines within the cluster.
          IpProtocol: "tcp"
          FromPort: "2000"
          ToPort: "2999"
          CidrIp: "10.0.0.0/8"
        }
        { # Free ports exposed to public Internet.
          IpProtocol: "tcp"
          FromPort: "3000"
          ToPort: "3999"
          CidrIp: "0.0.0.0/0"
        }
        { # Exposed to Internet for etcd. TODO: Lock down so only CoreOS can access.
          IpProtocol: "tcp"
          FromPort: "4001"
          ToPort: "4001"
          CidrIp: "0.0.0.0/0"
        }
        { # Exposed to Internet for clustering. TODO: Lock down so only CoreOS can access.
          IpProtocol: "tcp"
          FromPort: "7001"
          ToPort: "7001"
          CidrIp: "0.0.0.0/0"
        }
      ]

  # Return the augmented template object.
  template.Resources = resources
  return template


# Add unit to the cloud-config section of the AWS template.
add_unit = async (cloud_config, name, unit) ->
  # The cloud-config file is stored as an array of strings inside the "UserData"
  # object of the AWS template.  We wish to add additional strings to this array.
  # We need to be careful because "cloud-config" files are formatted in YAML,
  # which is sensitive to indentation....

  default_path = resolve __dirname, "formation-services/defaults.cson"
  unit = yield default_merge name, unit, default_path

  # Add to the cloud_config array.
  cloud_config.push "    - name: #{unit.output_filename}\n"
  cloud_config.push "      runtime: #{unit.runtime}\n"   if unit.runtime?
  cloud_config.push "      command: #{unit.command}\n"   if unit.command?
  cloud_config.push "      enable: #{unit.enable}\n"     if unit.enable?
  cloud_config.push "      content: |\n"

  # For "content", we draw from a unit-file maintained in a separate file. Add
  # eight spaces to the begining of each line (4 indentations) and follow each
  # line with an explicit new-line character.
  content = yield render_formation_service_template name, unit
  content = content.split "\n"

  while content.length > 0
    cloud_config.push "        " + content[0] + "\n"
    content.shift()

  return cloud_config


modules.export =
  # Build an AWS CloudFormation template by augmenting the official ones released by CoreOS.  Return a JSON string.
  build_template = async (options) ->
    try
      # Pull official CoreOS template as a JSON object.
      template_object = yield pull_cloud_template options

      # Configure this deployment's Virtual Private Cloud
      template_object = configure_vpc template_object

      # Configure this deployment's Security Group
      template_object = configure_security_group template_object




      # Modify the object specifying the cluster's LaunchConfig.  Associate with our new SecurityGroup.
      resources.CoreOSServerLaunchConfig["DependsOn"] = "ClusterGateway"
      resources.CoreOSServerLaunchConfig.Properties.SecurityGroups = [ {Ref: "ClusterSecurityGroup"} ]
      resources.CoreOSServerLaunchConfig.Properties.AssociatePublicIpAddress = "true"
      # Also give it a Spot Price if the user seeks to keep the cost down.
      if options.spot_price?
        resources.CoreOSServerLaunchConfig.Properties.SpotPrice = options.spot_price

      # Modify the object specifying the cluster's auto-scaling group.  Associate with the VPC.
      resources.CoreOSServerAutoScale["DependsOn"] = "ClusterGateway"
      resources.CoreOSServerAutoScale.Properties["VPCZoneIdentifier"] = [{Ref: "ClusterSubnet"}]
      resources.CoreOSServerAutoScale.Properties.AvailabilityZones = [options.availability_zone]

      # Associate the cluster's auto-scaling group with the user-specified tags.
      if options.tags? && options.tags.length > 0
        resources.CoreOSServerAutoScale.Properties.Tags = []
        for tag in options.tags
          new_tag = tag
          new_tag["PropagateAtLaunch"] = "true"
          resources.CoreOSServerAutoScale.Properties.Tags.push new_tag

      # Place "Resources" back into the JSON template object.
      template_object.Resources = resources

      #----------------------------
      # Cloud-Config Modifications
      #----------------------------
      # Isolate the cloud-config array within the JSON object.
      user_data = template_object.Resources.CoreOSServerLaunchConfig.Properties.UserData
      cloud_config = user_data["Fn::Base64"]["Fn::Join"][1]

      # Add the specified units to the cloud-config section.
      if options.formation_service_templates?
        for x of options.formation_service_templates
          cloud_config = yield add_unit cloud_config, x, options.formation_service_templates[x]

      # Add the specified public keys.  We must be careful with indentation formatting.
      unless !options.public_keys || options.public_keys == []
        cloud_config.push "ssh_authorized_keys: \n"
        for x in options.public_keys
          cloud_config.push "  - #{x}\n"

      # Place this array back into the JSON object.  Construction complete.
      user_data["Fn::Base64"]["Fn::Join"][1] = cloud_config
      template_object.Resources.CoreOSServerLaunchConfig.Properties.UserData = user_data

      # Return the JSON string.
      return JSON.stringify template_object, null, "\t"

    catch error
      console.log error
      return build_error "Unable to build CloudFormation template.", error
