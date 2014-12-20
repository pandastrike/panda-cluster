#!/bin/bash

# This Bash script adds SSH public keys to authorized_hosts for given IP addresses
# $1 = List of CloudFormation instances private IP addresses
# $2 = String file of SSH public keys
$2=${VARIABLE:-/tmp/pandacluster_authorized_hosts}

for address in $1 #FIXME: figure out how bash handles javascript string array input
do
  ssh $1 /usr/bin/bash << EOF
    scp $2 $1:~/.ssh/authorized_hosts
  EOF
done

echo ""
echo "The SSH public keys have been added to the CloudFormation instances"
echo ""
