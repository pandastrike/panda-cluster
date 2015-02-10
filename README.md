Panda-Cluster
============

### Awesome NodeJS Library to Manage CoreOS Clusters

---
[CoreOS][1] is an impressive technology that aims to change the way we approach Web deployment.  To describe it briefly, it is an operating system that is good at two things:

1. **Clustering** - CoreOS machines network efficiently.  Jobs are submitted and orchestrated at the cluster-level with the control system, [fleet][2].  All machines, by default, share a distributed key-store, [etcd][3].

2. **Running Docker Containers** - Applications on CoreOS run as [Docker][4] containers, providing flexibility and encouraging developers to write their apps as a collection of fault-tolerant [microservices][5].


The problem is that managing these clusters can be a little tedious.  Imagine that you want to spin-up a cluster of 10 CoreOS machines on Amazon Web Services (AWS).  You go find the [Amazon Machine Image provided by CoreOS][6], go through the five page Amazon Console wizard, and then make any other adjustments through the Console GUI.  This all involves a lot of manual interaction. panda-cluster is here to take care of that for you and make your life better.


## Installation
panda-cluster is available as an npm package.  How you install panda-cluster depends on how you'd like to use it.  Don't worry, both are easy.  However, it should be noted that panda-cluster makes use of the ES6 standards, promises and generators.  Using this library requires Node 0.11.2 or greater.

  ```shell
  git clone https://github.com/creationix/nvm.git ~/.nvm
  cd ~/.nvm
  git checkout `git describe --abbrev=0 --tags`
  source ~/.nvm/nvm.sh && nvm install 0.11
  nvm use 0.11
  ```

  Compiling the CoffeeScript requires coffee-script 1.9+.
  ```shell
  npm install -g coffee-script
  ```

### Command-Line Tool
If you'd like to use panda-cluster's command-line tool on your local machine, install it globally.

  ```
  npm install -g panda-cluster
  ```

This gives you a symlinked executable to invoke on your command-line.  See *Command-Line Guide* below for more information on this executable.

### Node Library
If you would like to install panda-cluster as a library and programmatically access its methods, install it locally to your project.

  ```
  npm install panda-cluster --save
  ```

This places the panda-cluster Node module into your project and in your `package.json` file as a dependency.  See *API Guide* below for more information on programatic access.

## Command-Line Guide
The command-line tool is accessed via several sub-commands.  Information is available at any time by placing "help" or "-h" after most commands.  Here is a list of currently available sub-commands.

  ```
  create          Creates a CoreOS cluster by allocating servers from AWS
  destroy         Terminates the specified CoreOS cluster and releases all resources.
  ```

## API Guide
To keep this ReadMe short, the API documentation has been placed into a separate file.  See the file *API Guide.md* for complete information.

### Configuration Dotfile
panda-cluster needs a fairly complex configuration object to function properly.  While it tries to start with some smart defaults, you'll still need to input a couple of required fields, and you'll need to specify what is to be launched into your cluster.

This data is stored in the dotfile `.panda-cluster.cson`. When used as a command-line tool, panda-cluster looks for the dotfile in your local `$HOME` directory (ie, at `~/.panda-cluster.cson`).  When used as a library, panda-cluster must be pointed to the project's dotfile.

TODO: Create a proper JSON Schema for panda-cluster.

Here is an example layout:

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

#=============================
# Cluster Description
#=============================
stack_name: "AppName"   # Required
key_pair: "KeyName"   # Required
channel: "stable"

hostname: "myapp.pandastrike.com"     # This is public hostname for the "head" machine.  You must own the domain.
private_hosted_zone: "myapp.cluster"  # This is only visible inside the cluster and may be whatever you like.

# **WARNING** - These affect the cost of your cluster.  See AWS Documentation for pricing.
instance_type: "m1.medium"
cluster_size: "3"
spot_price: "0.009"   # Tell panda-cluster to use Spot Instances at this hourly rate.
                      # Omit this line to use On-Demand Instances.
#=============================

# Optional Tag Descriptions
tags: [
  {
    Key: "Name"
    Value: "App Name"
  }
  {
    Key: "customer"
    Value: "foobar-inc"
  }
  {
    Key: "environment"
    Value: "dev"
  }
  {
    Key: "project"
    Value: "awesome"
  }
  {
    Key: "role"
    Value: "coreos"
  }
]


#=============================
# Template Descriptions
#=============================
# Template configurations of services that are needed *during* cluster formation.  These are limited
# to services that change properties of the instances themselves.
formation_service_templates:
  format_ephemeral: "default"
  var_lib_docker: "default"

# Template configuartions of services that can be deployed after the instances are online.  However,
# these services are deployed before panda-cluster declares your cluster ready for access.  Most
# services fall into this category.

# Each service file gets a sub-object below.  The members of each sub-object are used (via MustacheJS)
# to substitute values in the *.template files.
service_templates:
  elasticsearch:
    output_filename: "elasticsearch.service"
    after: ["docker.service"]
    container_name: "elasticsearch"
    image_name: "pandastrike/pc_elasticsearch"
    hostname: "elasticsearch.myapp.cluster"
    port: "2001"
    type: "A"


 kibana:
    output_filename: "kibana.service"
    after: ["docker.service", "elasticsearch.service"]
    container_name: "kibana"
    image_name: "pandastrike/pc_kibana"
    hostname: "kibana.myapp.pandastrike.com"
    port: "80"
    elasticsearch_url: "elasticsearch.myapp.cluster:2001"
```








[1]:https://coreos.com/
[2]:https://coreos.com/blog/cluster-level-container-orchestration/
[3]:https://coreos.com/using-coreos/etcd/
[4]:https://www.docker.com/
[5]:http://martinfowler.com/articles/microservices.html
[6]:https://coreos.com/docs/running-coreos/cloud-providers/ec2/
