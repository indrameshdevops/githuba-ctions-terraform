#!/bin/bash

# Terminate EC2 instances
aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output text | xargs -I {} aws ec2 terminate-instances --instance-ids {}

# Delete VPCs
aws ec2 describe-vpcs --query "Vpcs[].VpcId" --output text | xargs -I {} aws ec2 delete-vpc --vpc-id {}
