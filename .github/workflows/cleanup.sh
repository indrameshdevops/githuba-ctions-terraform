#!/bin/bash

set -e

# Print the commands being executed
set -x

echo "Starting cleanup process..."

# Terminate all EC2 instances
INSTANCE_IDS=$(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output text)
if [ -n "$INSTANCE_IDS" ]; then
  echo "Terminating EC2 instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
else
  echo "No EC2 instances found."
fi

# Wait for instances to be terminated
echo "Waiting for instances to be terminated..."
aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS

# Delete all VPCs
VPC_IDS=$(aws ec2 describe-vpcs --query "Vpcs[].VpcId" --output text)
if [ -n "$VPC_IDS" ]; then
  for VPC_ID in $VPC_IDS; do
    echo "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id $VPC_ID
  done
else
  echo "No VPCs found."
fi

echo "Cleanup process completed."
