#===============================================================================
# panda-cluster - CloudFormation Template Construction - VPC
#===============================================================================
# This file adds configuration details to the CloudFormation template related
# to a Virtual Private Cloud.  Each Huxley cluster gets its own, and it starts here.

module.exports =
  add: (template, spec) ->
    # Isolate the "Resources" object within the template.
    resources = template.Resources

    # Add an object specifying a VPC.
    resources["VPC"] =
      Type: "AWS::EC2::VPC"
      Properties:
        CidrBlock: "10.0.0.0/16"
        EnableDnsSupport: true
        EnableDnsHostnames: true
        Tags: [
          {
            Key: "Name"
            Value: spec.cluster.name
          }
        ]


    # Specify a subnet.
    resources["ClusterSubnet"] =
      Type: "AWS::EC2::Subnet"
      Properties:
        AvailabilityZone: spec.aws.availability_zone
        VpcId: { Ref: "VPC" }
        CidrBlock : "10.0.0.0/16"


    # Specify an Internet Gateway.
    resources["ClusterGateway"] =
      Type: "AWS::EC2::InternetGateway"
      Properties:
        Tags: [
          {
            Key: "Name"
            Value: spec.cluster.name
          }]

    # Specify the attachment of this Internet Gateway.
    resources["AttachClusterGateway"] =
      Type: "AWS::EC2::VPCGatewayAttachment"
      Properties:
        InternetGatewayId: {Ref: "ClusterGateway"}
        VpcId: {Ref: "VPC"}

    # Specify the creation of a new Route Table.
    resources["ClusterRouteTable"] =
      Type: "AWS::EC2::RouteTable"
      Properties:
        VpcId: {Ref: "VPC"}
        Tags: [
          {
            Key: "Name"
            Value: spec.cluster.name
          }]

    # Specify a Route for public addresses (through the Internet Gateway).
    resources["PublicRoute"] =
      Type: "AWS::EC2::Route"
      DependsOn: "ClusterGateway"
      Properties:
        DestinationCidrBlock: "0.0.0.0/0"
        GatewayId: {Ref: "ClusterGateway"}
        RouteTableId: {Ref: "ClusterRouteTable"}

    # Associate the new Route Table with our VPC.
    resources["AttachRouteTable"] =
      Type: "AWS::EC2::SubnetRouteTableAssociation"
      Properties:
        RouteTableId: {Ref: "ClusterRouteTable"}
        SubnetId: {Ref: "ClusterSubnet"}

    # Pass back the augmented template.
    template.Resources = resources
    return template
