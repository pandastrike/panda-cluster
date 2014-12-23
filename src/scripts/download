# This Bash script downloads authorized_hosts from given IP addresses
# $1 = List of CloudFormation instances private IP addresses
# $2 = Specified location to manipulate SSH keys
$2=${VARIABLE:-/tmp/pandacluster_authorized_hosts}

for address in $1 #FIXME: figure out how bash handles javascript string array input
do
  ssh $1 /usr/bin/bash << EOF
    scp $1:~/.ssh/authorized_hosts $2_$1
  EOF
done

echo ""
echo "The SSH public keys have been retrieved to the CloudFormation instances at $2" 
echo ""
