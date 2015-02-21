# PandaCluster API Guide
This guide aims to document and specify the API of PandaCluster when used as a Node library.

---
## create_cluster (options)
This function spins up a CoreOS cluster using AWS resources.  Clusters accept sophisticated configuration instructions.  This function starts with the "official" EC2 image maintained by CoreOS and adds customization.  To briefly describe: the cluster is installed in a Virtual Private Cloud, given a private Route53 hosted zone, and given a standard set of services that form cluster-infrastructure.  Please see [cluster-architecture.md][1] for more information.

### options - [See Schema][2]

## delete_cluster (options)
This function deletes a CoreOS cluster, meaning it stops and removes all EC2 machines involved, deletes the stack resources, and deletes any related resources (like DNS records).  This is not a suspension, but a total, irreversible destruction of the cluster.  

### options - [See Schema][3]

## get_cluster_status (options)
This function returns the status of CloudFormation stack that is used to run the EC2 instances.  This can be used during startup to determine when the instances are online, or during deletion to determine when resources have been released.  Use caution during cluster formation because additional installations are made to what is provided by CloudFormation. 

### options - [See Schema][4]

[1]:https://github.com/pandastrike/panda-cluster/blob/master/cluster-architecture.md
[2]:https://github.com/pandastrike/panda-cluster/blob/master/schema/create_cluster.json
[3]:https://github.com/pandastrike/panda-cluster/blob/master/schema/destroy_create.json
[4]:https://github.com/pandastrike/panda-cluster/blob/master/schema/get_cluster_status.json
