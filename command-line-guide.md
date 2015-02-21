# Command-Line Guide
Huxley is built around a Cluster-App-Microservice (CAM) model for deployment and continuous integration.  panda-cluster focuses on the cluster-level, the base and most permanent component of CAM.  It's designed to greatly simplify the manipulation of clusters by accessing your AWS and making API calls and/or shell commands on your behalf.

The command-line tool gives you quick access to the panda-cluster library via these sub-commands.  Information is available at any time by placing "help" or "-h" after most commands.  Here is a list of currently available sub-commands.

```
panda-cluster cluster create       Creates a CoreOS cluster by allocating servers from AWS
panda-cluster cluster delete     Terminates the specified CoreOS cluster and releases all resources.
```

## EC2 Spot Instances
When launching a cluster, you have the option of using Spot Instances and setting a price limit.  Spot Instances are charged with a variable rate and are interrupted when the price exceeds your limit.  However, they offer significant (~90%) savings, so they are great for testing.  They are recommended if they are compatible with your project needs.
- [AWS EC2 Pricing][1]
- [AWS Spot Instance Pricing][2]


## Configuration Dotfile
Not all configuration data is entered via flags on the command-line.  This dotfile is used to store your AWS credentials and an array of public SSH keys for cluster access  Since this data is sensitive and doesn't change much between uses, it is placed into your local $HOME directory instead of your repository.  The command-line tool will read this file whenever you run a command.

### .panda-cluster.cson
> ***NEVER PLACE THIS IN YOUR PROJECT'S REPOSITORY!!***

```coffee
aws:
  id: "MyAWSIdentity"
  key: "Password123"
  region: "us-west-1"

public_keys: [
  "This should be",
  "a series of strings",
  "that are comma separated.",
  "One line per key."
]
```

[1]:http://aws.amazon.com/ec2/pricing/
[2]:http://aws.amazon.com/ec2/purchasing-options/spot-instances/
