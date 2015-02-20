Panda-Cluster is built around a Cluster-App-Microservice (CAM) model for deployment,
allowing it to understand and gracefully manipulate clusters running in your AWS account.

A cluster is the base and most permanent component of that model.  Each comes equipped with
a private DNS and sidekicks support servers.

The following subcommands manipulate clusters by accessing your AWS account and
automating the necessary commands.

The command-line tool is accessed via several sub-commands.  Information is available at any time by placing "help" or "-h" after most commands.  Here is a list of currently available sub-commands.

```
create          Creates a CoreOS cluster by allocating servers from AWS
destroy         Terminates the specified CoreOS cluster and releases all resources.
```
