# Cluster Architecture
Huxley is built around a Cluster-App-Microservice (CAM) model for deployment and continuous integration.  This allows it to understand and gracefully manipulate what you have running in your AWS account.  panda-cluster's scope is the cluster-level component.  What follows is a description of what this library builds for you.

## Clustering Docker Containers
panda-cluster starts with the CloudFormation template of a CoreOS cluster.  This template is a set of EC2 instances that is already an impressive platform, but panda-cluster takes it further.  We install the cluster in an AWS Virtual Private Cloud (VPC), which gives us a lot of power. Using the VPC, we establish SecurityGroups and a private Route53 hosted zone.  We can freely create hostnames that are either exposed to the public Internet or available only within the cluster.

You shouldn't think of this as cluster of 3 (or more) EC2 instances.  The above addressing allows us to setup a logical cluster of perhaps dozens of Docker containers.  And because we have both public and private cluster domains, you can securely create arbitrary network toplogies with your containers.  

## The Semi-Autonomous Cluster
It's not enough to setup the public and private cluster domains.  You need to be able to efficiently deploy your code to the cluster and keep it updated.  Once you have your services established, you'll need to register them with the DNS server.  panda-cluster builds a cluster that has you covered.

Each cluster comes equipped with servers that act as your agents within the cluster.

### The Hook Server
The hook-server (short for git webhook) is the cluster-level git repository for your code.  This serves two purposes.

- We use the repo to store a githook.  This is a deployment script that gets triggered when we `git push` to the hook-server.  A sophisticated, multi-container app may be deployed by a single git command.  Githooks are built and placed using the tool [panda-hook][1], since they are not normally transfered with git commands.

- Services may pull from this repo when they deploy.  This is especially important for private repositories.  Services don't need special credentials, making them more interchangeable.  Your private repo is securely exposed to the whole cluster, but not the Internet.

### The Kick Server
The kick-server (short for sidekick) is your proxy on the cluster.  It's a a Node server with your AWS credentials.  Your credentials remain safe because the kick-server is not exposed to the public Internet.  However, services may make simple HTTP requests into the kick-server and request an action.  You'll never have to fuss with the AWS Console to get your services setup.

In the current iteration, the kick-server is used by services to alter either public or private DNS records.  However, as the feature-set of Huxley clusters grow, the kick-server can accept requests for other actions.  

Please see the [panda-kick project][2] to see the kick-server's codebase.

[1]:https://github.com/pandastrike/panda-hook
[2]:https://github.com/pandastrike/panda-kick
