#===============================================================================
# panda-cluster - EC2 Instances
#===============================================================================
# Return a library of functions that handle both types of EC2 instance allocation.
# We'll need to manipulate these virtual machines until we move to a direct-container
# allocation, a near-to-medium term goal.

module.exports =
  # EC2 Instance Class-Specific Functions
  demand: require "./demand" # On-Demand Instances
  spot: require "./spot"     # Spot Instances

  # General Functions
  delete: require "./delete"    # AWS "terminate" functionality.  Irreversable.
