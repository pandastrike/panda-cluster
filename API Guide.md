# PandaCluster API Guide
This guide aims to document and specify the API of PandaCluster when used as a Node library.

[Create][0]
[Destroy][1]

### Credentials
All of the following methods access your AWS account to do things for you automatically.  Getting that access means they'll need your AWS credentials.  Remember to never hardcode your credentials into your project.  

The object `credentials` is passed into most of the below functions and contains the following members:

```coffee
credentials =
  id: "myID"
  secret: "password123"
  region: "us-west-1"
```


## Create (credentials, options)
This function spins up a CoreOS cluster using AWS and takes special instructions through "options":
### Options
- **stack_name**: *Required* (string) Name of cluster. Alpha-numeric string of at most 255 characters.
- **key_pair**: *Required* (string) Name of SSH keypair.  Access to the cluster is achieved via an SSH connection.  The public key with this name is placed onto every CoreOS machine.
- **cluster_size**: (number) [Default = 3]  Clusters must have between 3 and 12 machines, inclusive.
- **Template File.** (string)  This is a string containing a path to the AWS template file.  The path should be absolute and include the template filename.
- **instance_type**: (string) [Default = "m3.medium"]  All machines in the cluster are of the same type. You may select between the following EC2 instance types:
  "c1.medium", "c1.xlarge",
  "c3.large", "c3.xlarge", "c3.2xlarge", "c3.4xlarge", "c3.8xlarge",
  "hi1.4xlarge", "hs1.8xlarge",
  "m1.medium", "m1.large", "m1.xlarge",
  "m2.xlarge", "m2.2xlarge", "m2.4xlarge",
  "m3.medium", "m3.large", "m3.xlarge", "m3.2xlarge",
  "t1.micro"


## Destroy (credentials, options)
This function terminates a CoreOS cluster, meaning it stops and removes all EC2 machines involved and deletes the stack resources.  This is a pretty straight-forward function.  The only member of options is:
- **stack_name**: *Required* (string) Name of cluster. Alpha-numeric string of at most 255 characters.
