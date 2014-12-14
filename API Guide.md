# PandaCluster API Guide
This guide aims to document and specify the API of PandaCluster when used as a Node library.


### credentials
All of the following methods access your AWS account to do things for you automatically.  Getting that access means they'll need your AWS credentials.  Remember to never hardcode your credentials into your project.  

The object `credentials` is passed into most of the below functions and contains the following members:

```coffee
credentials =
  id: "myID"
  secret: "password123"
  region: "us-west-1"
```


## build_template([options])
This function pulls an official AWS CloudFormation template from the CoreOS's public S3 bucket and customizes it according to your specifications.  This template is used to configure the cluster to your needs.

### options
This argument is optional.  It is an object with the following members, all of which are optional:

**channel** - (Default = "stable")  CoreOS provides rolling updates across a three-tier stability scheme.  "stable" contains a version that has been through extensive battle-testing and debugging, while "beta" and "alpha" contain newer features and dependency versions.

  Allowed values: `"stable", "beta", "alpha"`

**write_path** - Path for the final AWS CloudFormation template file, containing a JSON string. The path is relative to your working directory and includes the filename.  When no path is provided, this function returns a stringified JSON object containing the template.

**virtualization** - Virtualization Type. (Default = "pv").  Amazon offers two types of virtualization, Para-Virtualization (PV) and and Hardware-assisted Virtual Machine (HVM).  In short, PV has better performance, but HVM is more stable.

  Allowed Values: `"pv", "hvm"`

**units** -  Path for the unit configuration file. (Default = null)  This file is a CSON object that holds relevant CoreOS unit configuration data.  The path is relative to your working directory and includes the filename.  Units conform to CoreOS's systemd format, and samples are available [here](https://github.com/pandastrike/PandaCluster/tree/master/units).  These unit files do a lot for you.  The linked directory contains some basic ones from CoreOS, exposing and adding ephemeral storage to the Docker Host.

## Create (credentials, options)
This function spins up a CoreOS cluster using AWS and takes special instructions through "options":
### options
This is an object with the following members:

- **stack_name**: *Required* (string) Name of cluster. Alpha-numeric string of at most 255 characters.

- **key_pair**: *Required* (string) Name of SSH keypair.  Access to the cluster is achieved via an SSH connection.  AWS has named public SSH keys associated with your account.  The public key with this name is placed onto every CoreOS machine, and this function fails if it cannot be found.

- **cluster_size**: (number) [Default = 3]  Specifies the number of EC2 machines in your CoreOS cluster.  Clusters must have between 3 and 12 machines, inclusive.

- **template_path.** (string)  (Default = "Stable" Channel AMI using PV). This is a string containing a path to the AWS template file.  The path is relative to your working directory and include the template filename. If no template file is provided, PandaCluster pulls the latest CoreOS AMI from the "stable" channel and requests a build using para-virtualization (PV).

- **instance_type**: (enumerated string) [Default = "m3.medium"]  Select the EC2 instance type for the cluster.  All machines in the cluster are of the same type.

  Allowed Values:
  ```
  "c1.medium", "c1.xlarge",
  "c3.large", "c3.xlarge", "c3.2xlarge", "c3.4xlarge", "c3.8xlarge",
  "hi1.4xlarge", "hs1.8xlarge",
  "m1.medium", "m1.large", "m1.xlarge",
  "m2.xlarge", "m2.2xlarge", "m2.4xlarge",
  "m3.medium", "m3.large", "m3.xlarge", "m3.2xlarge",
  "t1.micro"
  ```
- **region** - AWS Region.  Your default region is set in the `credentials` object, but you may temporarily override that region for this command.

  Allowed Values:
  `"ap-northeast-1", "ap-southeast-1", "ap-southeast-2", "eu-central-1", "eu-west-1", "sa-east-1", "us-east-1", "us-west-1", "us-west-2"`


## destroy (credentials, options)
This function terminates a CoreOS cluster, meaning it stops and removes all EC2 machines involved and deletes the stack resources.  

### options
This is a pretty straight-forward function.  Options is an object, but its only member is:

- **stack_name**: *Required* (string) Name of cluster. Alpha-numeric string of at most 255 characters.
