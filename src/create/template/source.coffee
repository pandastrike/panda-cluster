#===============================================================================
# panda-cluster - CoreOS Image Templates
#===============================================================================
# This file specifies CoreOS cloud images for PV and HVM machines that AWS
# offers. The values "stable", "beta", and "alpha" refer to CoreOS "channels".

module.exports =
  stable:
    pv: "https://s3.amazonaws.com/coreos.com/dist/aws/coreos-stable-pv.template"
    hvm: "https://s3.amazonaws.com/coreos.com/dist/aws/coreos-stable-hvm.template"
  beta:
    pv: "https://s3.amazonaws.com/coreos.com/dist/aws/coreos-beta-pv.template"
    hvm: "https://s3.amazonaws.com/coreos.com/dist/aws/coreos-beta-hvm.template"
  alpha:
    pv: "https://s3.amazonaws.com/coreos.com/dist/aws/coreos-alpha-pv.template"
    hvm: "https://s3.amazonaws.com/coreos.com/dist/aws/coreos-alpha-hvm.template"
