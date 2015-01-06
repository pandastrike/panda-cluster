PandaCluster
============

### Awesome Command-Line Tool and Library to Manage CoreOS Clusters

---
[CoreOS][1] is an impressive technology that aims to change the way we approach Web deployment.  To describe it briefly, it is an operating system that is good at two things:

1. **Clustering** - CoreOS machines network efficiently.  Jobs are submitted and orchestrated at the cluster-level with the control system, [fleet][2].  All machines, by default, share a distributed key-store, [etcd][3].

2. **Running Docker Containers** - Applications on CoreOS run as [Docker][4] containers, providing flexibility and encouraging developers to write their apps as a collection of fault-tolerant [microservices][5].


The problem is that managing these clusters can be a little tedious.  Imagine that you want to spin-up a cluster of 10 CoreOS machines on Amazon Web Services (AWS).  You go find the [Amazon Machine Image provided by CoreOS][6], go through the five page Amazon Console wizard, and then make any other adjustments through the Console GUI.  This all involves a lot of manual interaction. PandaCluster is here to take care of that for you and make your life better.


## Installation
PandaCluster is available as an npm package.  How you install PandaCluster depends on how you'd like to use it.  Don't worry, both are easy.  However, it should be noted that PandaCluster makes use of the ES6 standards, promises and generators.  Using this library requires Node 0.11.2 or greater.

  ```shell
  git clone https://github.com/creationix/nvm.git ~/.nvm
  cd ~/.nvm
  git checkout `git describe --abbrev=0 --tags`
  source ~/.nvm/nvm.sh && nvm install 0.11
  nvm use 0.11
  ```

  Compiling the CoffeeScript requires the latest development branch of version 1.8.
  ```shell
  npm install -g jashkenas/coffee-script
  ```

### Command-Line Tool
If you'd like to use PandaCluster's command-line tool on your local machine, install it globally.

  ```
  npm install -g pandacluster
  ```

This gives you a symlinked executable to invoke on your command-line.  See *Command-Line Guide* below for more information on this executable.

### Node Library
If you would like to install PandaCluster as a library and programmatically access its methods, install it locally to your project.

  ```
  npm install pandacluster --save
  ```

This places the PandaCluster Node module into your project and in your `package.json` file as a dependency.  See *API Guide* below for more information on programatic access.

## Command-Line Guide
The command-line tool is accessed via several sub-commands.  Information is available at any time by placing "help" or "-h" after most commands.  Here is a list of currently available sub-commands.

  ```
  build_template  Builds an AWS CloudFormation template using images released by CoreOS
  create          Creates a CoreOS cluster by allocating servers from AWS
  destroy         Terminates the specified CoreOS cluster
  ```

## API Guide
To keep this ReadMe short, the API documentation has been placed into a separate file.  See the file *API Guide.md* for complete information.

### Configuration Dotfile
To access AWS, PandaCluster will need your credentials.  This data is stored in the dotfile `.pandacluster.cson`. When used as a command-line tool, PandaCluster looks for the dotfile in your local `$HOME` directory (ie, at `~/.pandacluster.cson`).  When used as a library, PandaCluster must be pointed to the project's dotfile.

Here is an example layout:

```coffee
aws:
  id: "myID"
  secret: "password123"
  region: "us-west-1"
```








[1]:https://coreos.com/
[2]:https://coreos.com/blog/cluster-level-container-orchestration/
[3]:https://coreos.com/using-coreos/etcd/
[4]:https://www.docker.com/
[5]:http://martinfowler.com/articles/microservices.html
[6]:https://coreos.com/docs/running-coreos/cloud-providers/ec2/
