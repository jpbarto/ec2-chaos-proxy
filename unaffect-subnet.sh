#!/usr/bin/env bash

set -e

###
## Configure a subnet to route traffic to the local chaos gateway.
###

SUBNET=$1
echo Preparing to reset the route table for $SUBNET...

REGION=${AWS_DEFAULT_REGION:-us-east-1}
AZ=$(aws ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[].AvailabilityZone' --output text --region $REGION)
VPC_ID=$(aws ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[].VpcId' --output text --region $REGION)
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[].CidrBlock' --output text --region $REGION)  

ORIG_ROUTE_TABLE_ID=$(aws ec2 describe-tags \
    --filters Name=resource-id,Values=$SUBNET Name=key,Values=rollback-route-table \
    --query 'Tags[0].Value' \
    --output text --region $REGION)

# replace target subnet route table with it's original route table
# get association id for subnet
GW_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
            --query 'RouteTables[*].Associations[?SubnetId==`'$SUBNET'`].RouteTableId' \
            --output text --region $REGION)
ASSOC_ID=$(aws ec2 describe-route-tables \
            --query 'RouteTables[*].Associations[?SubnetId==`'$SUBNET'`].RouteTableAssociationId' \
            --output text --region $REGION)

echo Restoring the route table associations for $SUBNET...
# disassociate existing route table
aws ec2 disassociate-route-table --association-id $ASSOC_ID --region $REGION
if [ "$ORIG_ROUTE_TABLE_ID" != "None" ]; then
    # re-associate the original route table
    aws ec2 associate-route-table \
        --subnet-id $SUBNET \
        --route-table-id $ORIG_ROUTE_TABLE_ID \
        --query 'AssociationState' --region $REGION
    # clear the tag set previously
    aws ec2 delete-tags --resources $SUBNET --tags Key=rollback-route-table,Value=$ORIG_ROUTE_TABLE_ID --region $REGION
fi

echo Deleting the old route table $GW_ROUTE_TABLE_ID...
# delete the old route table
aws ec2 delete-route-table --route-table-id $GW_ROUTE_TABLE_ID --region $REGION
