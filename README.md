Panda-Cluster
============

### Awesome NodeJS Library to Manage CoreOS Clusters
---
> **Warning:** This is an experimental project under heavy development.  It's awesome and becoming even more so, but it is a work in progress.

[CoreOS][1] is an impressive technology that aims to change the way we approach Web deployment.  To describe it briefly, it is an operating system that is good at two things:

1. **Clustering** - CoreOS machines network efficiently.  Jobs are submitted and orchestrated at the cluster-level with the control system, [fleet][2].  All machines, by default, share a distributed key-store, [etcd][3].

2. **Running Docker Containers** - Applications on CoreOS run as [Docker][4] containers, providing flexibility and encouraging developers to write their apps as a collection of fault-tolerant [microservices][5].


The problem is that managing these clusters can be a little tedious.  Imagine that you want to spin-up a cluster of 10 CoreOS machines on Amazon Web Services (AWS):
- You go find the [Amazon Machine Image provided by CoreOS][6]
- go through the five page Amazon Console wizard
- and then figet with the Console GUI to make any other adjustments.  

That all involves a lot of manual interaction. Panda-Cluster is here to take care of that for you and make your life better.


## Requirements
panda-cluster makes use of the ES6 standards, promises and generators.  Using this library requires Node 0.12+.

```shell
git clone https://github.com/creationix/nvm.git ~/.nvm
source ~/.nvm/nvm.sh && nvm install 0.12
```

Compiling the ES6 compliant CoffeeScript requires `coffee-script` 1.9+.
```shell
npm install -g coffee-script
```

## Command-Line Tool - Quick Start
To try this out quickly, you can use panda-cluster's command-line tool on your local machine.  If you install the package globally, you get an executable CLI tool that accesses library functions, but it is relatively minimal.

```
npm install pandastrike/panda-cluster -g
```

Next, you'll need to place `.panda-cluster.cson` into your $HOME directory.  This is how panda-cluster accesses AWS on your behalf.

### .panda-cluster.cson
```coffee
aws:
id: "MyAWSIdentity"
key: "Password123"
region: "us-west-1"
```
> **WARNING:** ***NEVER PLACE THIS IN YOUR PROJECT'S REPOSITORY***!!

<br><br>
Now, all you need to do is run this command and you'll have a cluster of your own!  Please see [cluster-architecture.md][9] to learn more about what this command builds.
```shell
panda-cluster cluster create -n <cluster_name> -d <public_domain_you_own> -k <name_of_ssh_key_in_your_aws_account> -p myapp.cluster -o 0.009 -m true
```

> **WARNING:** This command will cause *your* AWS account to be charged according to your EC2 usage.  Use of the "-o" flag greatly reduces the cost, so it is preferable for testing.


<br><br>
This was just a quick intro, so please see [command-line-guide.md][7] for more information on the configuration file and this executable.

## Node Library
If you would like to install panda-cluster as a library and programmatically access its methods, install it locally to your project.

```json
npm install pandastrike/panda-cluster --save
```

See [api-guide.md][8] for more information on programatic access.

## Command-Line Guide
To keep this ReadMe short, the command-line documentation has been placed into a separate file.  See the file [command-line-guide.md][7] for complete information.

## API Guide
To keep this ReadMe short, the API documentation has been placed into a separate file.  See the file [api-guide.md][8] for complete information.


[1]:https://coreos.com/
[2]:https://coreos.com/blog/cluster-level-container-orchestration/
[3]:https://coreos.com/using-coreos/etcd/
[4]:https://www.docker.com/
[5]:http://martinfowler.com/articles/microservices.html
[6]:https://coreos.com/docs/running-coreos/cloud-providers/ec2/
[7]:https://github.com/pandastrike/panda-cluster/blob/master/command-line-guide.md
[8]:https://github.com/pandastrike/panda-cluster/blob/master/api-guide.md
[9]:https://github.com/pandastrike/panda-cluster/blob/master/cluster-architecture.md
