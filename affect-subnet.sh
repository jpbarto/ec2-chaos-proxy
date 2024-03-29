#!/usr/bin/env bash

set -e

###
## Configure a subnet to route traffic to the local chaos gateway.
###

source chaos-gateway-subnets.sh

SUBNET=$1
echo Preparing to replace the route table for $SUBNET...

REGION=${AWS_DEFAULT_REGION:-us-east-1}
AZ=$(aws ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[].AvailabilityZone' --output text --region $REGION)
VPC_ID=$(aws ec2 describe-subnets --subnet-ids $SUBNET --query 'Subnets[].VpcId' --output text --region $REGION)
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[].CidrBlock' --output text --region $REGION)  

# detect the chaos gateway local to the subnet's AZ
GW_ID=$(aws ec2 describe-instances \
        --query 'Reservations[].Instances[?(VpcId==`'$VPC_ID'`) && (Tags[?Key==`ChaosGW`]) && (Placement.AvailabilityZone==`'$AZ'`)].InstanceId' \
        --output text --region $REGION)

# create a new route table
GW_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text --region $REGION)
echo Created new route table: ${GW_ROUTE_TABLE_ID}.

# modify it to send all traffic to the chaos gateway
aws ec2 create-route --route-table-id $GW_ROUTE_TABLE_ID --instance-id $GW_ID --destination-cidr-block '0.0.0.0/0'

# update the default route for the local CIDRs to point to chaos gateway
JMES_SET='`'${CHAOS_GW_SUBNETS[0]}'`'
for subnet in "${CHAOS_GW_SUBNETS[@]}";
do
        JMES_SET+=',`'${subnet}'`';
done
REDIRECT_CIDRS=($(aws ec2 describe-subnets \
        --region $REGION \
        --query 'Subnets[? (VpcId==`'${VPC_ID}'`) && (!contains(['${JMES_SET}'] | @, SubnetId))].CidrBlock' \
        --output text))
for redirect_cidr in "${REDIRECT_CIDRS[@]}";
do
        aws ec2 create-route --route-table-id $GW_ROUTE_TABLE_ID --instance-id $GW_ID --destination-cidr-block ${redirect_cidr}
done

# replace target subnet route table with new route table
# get association id for subnet
ORIG_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
            --query 'RouteTables[*].Associations[?SubnetId==`'$SUBNET'`].RouteTableId' \
            --output text --region $REGION)
ASSOC_ID=$(aws ec2 describe-route-tables \
            --query 'RouteTables[*].Associations[?SubnetId==`'$SUBNET'`].RouteTableAssociationId' \
            --output text --region $REGION)

if [ ! -z $ASSOC_ID ]; then
    echo Tagging the subnet with its original Route Table ID 
    aws ec2 create-tags --resource ${SUBNET} --tags Key=rollback-route-table,Value=${ORIG_ROUTE_TABLE_ID}
    echo Swapping the old route table $ORIG_ROUTE_TABLE_ID for the new route table $GW_ROUTE_TABLE_ID...
    # disassociate existing route table
    aws ec2 disassociate-route-table --association-id $ASSOC_ID --region $REGION
else
    echo Subnet uses the VPC default routing table
fi

echo To restore execute "./unaffect-subnet.sh ${SUBNET}"
# associate new route table
aws ec2 associate-route-table --subnet-id $SUBNET --route-table-id $GW_ROUTE_TABLE_ID --region $REGION
