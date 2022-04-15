#!/usr/bin/env bash

set -e

###
## Configure a subnet to route traffic to the local chaos gateway.
###

SUBNET=$1
ORIG_ROUTE_TABLE_ID=$2
echo Preparing to reset the route table for $SUBNET...

REGION=${AWS_DEFAULT_REGION:-us-east-1}
AZ=$(aws ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[].AvailabilityZone' --output text --region $REGION)
VPC_ID=$(aws ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[].VpcId' --output text --region $REGION)
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[].CidrBlock' --output text --region $REGION)  

# replace target subnet route table with new route table
# get association id for subnet
GW_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
            --query 'RouteTables[*].Associations[?SubnetId==`'$SUBNET'`].RouteTableId' \
            --output text --region $REGION)
ASSOC_ID=$(aws ec2 describe-route-tables \
            --query 'RouteTables[*].Associations[?SubnetId==`'$SUBNET'`].RouteTableAssociationId' \
            --output text --region $REGION)

echo Restoring the route table $ORIG_ROUTE_TABLE_ID to $SUBNET...
# disassociate existing route table
aws ec2 disassociate-route-table --association-id $ASSOC_ID --region $REGION
# associate new route table
aws ec2 associate-route-table --subnet-id $SUBNET --route-table-id $ORIG_ROUTE_TABLE_ID --query 'AssociationState' --region $REGION

echo Deleting the old route table $GW_ROUTE_TABLE_ID...
# delete the old route table
aws ec2 delete-route-table --route-table-id $GW_ROUTE_TABLE_ID --region $REGION