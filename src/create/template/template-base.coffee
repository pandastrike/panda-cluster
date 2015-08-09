#===============================================================================
# panda-cluster - CloudFormation
#===============================================================================
# We use AWS CloudFormation to lay the foundation of a Huxley cluster, like its
# VPC.  This automates a lot of the boring details needed to establish one.

module.exports =
  AWSTemplateFormatVersion: "2010-09-09"
  Description: "Huxley Cluster - Forms skeleton to organize cloud resources that will be allocated on-demand."
  Resources: {}
