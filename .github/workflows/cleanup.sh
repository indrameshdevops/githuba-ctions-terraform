#!/bin/bash

set -e
set -x

echo "Starting cleanup process..."

# Identify the default VPC
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[?IsDefault].VpcId" --output text)
echo "Default VPC ID: $DEFAULT_VPC_ID"

# Get the CIDR block for the default VPC
DEFAULT_VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids ${DEFAULT_VPC_ID} --query "Vpcs[].CidrBlock" --output text)
echo "Default VPC CIDR Block: $DEFAULT_VPC_CIDR"

# Identify the default route table (main route table)
DEFAULT_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --filters "Name=association.main,Values=true" --query "RouteTables[].RouteTableId" --output text)
echo "Default Route Table ID: $DEFAULT_ROUTE_TABLE_ID"

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

# Delete all subnets, except default subnets
SUBNET_IDS=$(aws ec2 describe-subnets --query "Subnets[?VpcId != '${DEFAULT_VPC_ID}'].SubnetId" --output text)
if [ -n "$SUBNET_IDS" ]; then
  for SUBNET_ID in $SUBNET_IDS; do
    echo "Deleting subnet: $SUBNET_ID"
    aws ec2 delete-subnet --subnet-id $SUBNET_ID
  done
else
  echo "No subnets found."
fi

# Retrieve all route tables
ALL_ROUTE_TABLES=$(aws ec2 describe-route-tables --query "RouteTables[].{ID:RouteTableId,Main:Associations[0].Main}" --output json)

# Process each route table
for ROW in $(echo "${ALL_ROUTE_TABLES}" | jq -c '.[]'); do
  ROUTE_TABLE_ID=$(echo "$ROW" | jq -r '.ID')
  IS_MAIN=$(echo "$ROW" | jq -r '.Main')

  # Skip the default (main) route table
  if [ "$IS_MAIN" = "true" ]; then
    echo "Skipping main route table: $ROUTE_TABLE_ID"
    continue
  fi

  echo "Processing route table: $ROUTE_TABLE_ID"

  # Disassociate route table from subnets
  ASSOCIATED_SUBNET_IDS=$(aws ec2 describe-route-tables --route-table-ids ${ROUTE_TABLE_ID} --query "RouteTables[].Associations[].SubnetId" --output text)
  if [ -n "$ASSOCIATED_SUBNET_IDS" ]; then
    for SUBNET_ID in $ASSOCIATED_SUBNET_IDS; do
      echo "Disassociating route table $ROUTE_TABLE_ID from subnet $SUBNET_ID"
      ASSOCIATION_ID=$(aws ec2 describe-route-tables --route-table-ids ${ROUTE_TABLE_ID} --query "RouteTables[].Associations[?SubnetId=='${SUBNET_ID}'].AssociationId" --output text)
      aws ec2 disassociate-route-table --association-id $ASSOCIATION_ID
    done
  else
    echo "No subnets associated with route table $ROUTE_TABLE_ID."
  fi

  # Remove all non-local routes
  ROUTES=$(aws ec2 describe-route-tables --route-table-ids ${ROUTE_TABLE_ID} --query "RouteTables[].Routes[?DestinationCidrBlock != '${DEFAULT_VPC_CIDR}'].DestinationCidrBlock" --output text)
  if [ -n "$ROUTES" ]; then
    for ROUTE in $ROUTES; do
      echo "Deleting route $ROUTE from route table $ROUTE_TABLE_ID"
      aws ec2 delete-route --route-table-id ${ROUTE_TABLE_ID} --destination-cidr-block $ROUTE
    done
  else
    echo "No non-local routes found in route table $ROUTE_TABLE_ID."
  fi

  # Delete route table
  echo "Deleting route table: $ROUTE_TABLE_ID"
  aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID
done

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
