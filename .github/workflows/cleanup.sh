#!/bin/bash

set -e
set -x

echo "Starting cleanup process..."

# Identify the default VPC
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[?IsDefault].VpcId" --output text)

echo "Default VPC ID: $DEFAULT_VPC_ID"

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

# Delete all subnets, except those in the default VPC
SUBNET_IDS=$(aws ec2 describe-subnets --query "Subnets[?VpcId != '${DEFAULT_VPC_ID}'].SubnetId" --output text)
if [ -n "$SUBNET_IDS" ]; then
  for SUBNET_ID in $SUBNET_IDS; do
    echo "Deleting subnet: $SUBNET_ID"
    aws ec2 delete-subnet --subnet-id $SUBNET_ID
  done
else
  echo "No subnets found."
fi

# Delete all route tables, except those in the default VPC
ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --query "RouteTables[?VpcId != '${DEFAULT_VPC_ID}'].RouteTableId" --output text)
if [ -n "$ROUTE_TABLE_IDS" ]; then
  for ROUTE_TABLE_ID in $ROUTE_TABLE_IDS; do
    echo "Deleting route table: $ROUTE_TABLE_ID"
    aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID
  done
else
  echo "No route tables found."
fi

# Delete all network interfaces, except those in the default VPC
NETWORK_INTERFACE_IDS=$(aws ec2 describe-network-interfaces --query "NetworkInterfaces[?VpcId != '${DEFAULT_VPC_ID}'].NetworkInterfaceId" --output text)
if [ -n "$NETWORK_INTERFACE_IDS" ]; then
  for NETWORK_INTERFACE_ID in $NETWORK_INTERFACE_IDS; do
    echo "Deleting network interface: $NETWORK_INTERFACE_ID"
    aws ec2 delete-network-interface --network-interface-id $NETWORK_INTERFACE_ID
  done
else
  echo "No network interfaces found."
fi

# Delete all VPCs, except the default VPC
VPC_IDS=$(aws ec2 describe-vpcs --query "Vpcs[?VpcId != '${DEFAULT_VPC_ID}'].VpcId" --output text)
if [ -n "$VPC_IDS" ]; then
  for VPC_ID in $VPC_IDS; do
    echo "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id $VPC_ID
  done
else
  echo "No VPCs found."
fi

echo "Cleanup process completed."
