#===============================================================================
# panda-cluster - CloudFormation Template Construction - Auto Scaling
#===============================================================================
# This file adds configuration details to the CloudFormation template related
# to a auto scaling. Currently, no scaling automation is setup.  These fields
# are useful in establishing a bid price for instances in the cluster.

module.exports =
  add: (template, spec) ->
    # Isolate the "Resources" object within the template.
    resources = template.Resources

    # Modify the object specifying the cluster's LaunchConfig.  Associate with our new SecurityGroup.
    resources.CoreOSServerLaunchConfig["DependsOn"] = "ClusterGateway"
    resources.CoreOSServerLaunchConfig.Properties.SecurityGroups = [ {Ref: "ClusterSecurityGroup"} ]
    resources.CoreOSServerLaunchConfig.Properties.AssociatePublicIpAddress = "true"
    # Also give it a Spot Price if the user seeks to keep the cost down.
    if Number(spec.cluster.price) > 0
      resources.CoreOSServerLaunchConfig.Properties.SpotPrice = spec.cluster.price.toString()

    # Modify the object specifying the cluster's auto-scaling group.  Associate with the VPC.
    resources.CoreOSServerAutoScale["DependsOn"] = "ClusterGateway"
    resources.CoreOSServerAutoScale.Properties["VPCZoneIdentifier"] = [{Ref: "ClusterSubnet"}]
    resources.CoreOSServerAutoScale.Properties.AvailabilityZones = [spec.aws.availability_zone]

    # Associate the cluster's auto-scaling group with the user-specified tags.
    if spec.tags && spec.tags.length > 0
      resources.CoreOSServerAutoScale.Properties.Tags = []
      for tag in spec.cluster.tags
        new_tag = tag
        new_tag["PropagateAtLaunch"] = "true"
        resources.CoreOSServerAutoScale.Properties.Tags.push new_tag

    # Pass back the augmented template.
    template.Resources = resources
    return template
