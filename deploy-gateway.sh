#!/usr/bin/env bash

set -e

function print_help {
    echo "Usage: $0 <SUBNET-ID-1> <SUBNET-ID-2> <SUBNET-ID-3>"
    echo
    echo "NOTE: Ensure that the AWS_DEFAULT_REGION environment variable"
    echo "      is set to an AWS region which hosts the specified subnet IDs."
    echo
    echo "SUBNET-ID-X   The ID of the Subnet into which the chaos proxy instance"
    echo "              should be deployed.  All subnets should be part of the"
    echo "              same VPC."
}

if [ $# -eq 0 ] || [ $1 == "-h" ] || [ $1 == "--help" ]; then
    print_help
    exit 1
fi

ARGV=("$@")

REGION=${AWS_DEFAULT_REGION}

NUM_SUBNETS=${#ARGV[@]}
SUBNET_0=${ARGV[0]}
SUBNETS=${SUBNET_0}
for subnet in "${ARGV[@]:1}";
do
    SUBNETS+="\,${subnet}";
done

echo Detecting VPC ID using subnet ${SUBNET_0}...
VPC_ID=$(aws ec2 describe-subnets --subnet-ids ${SUBNET_0} --query 'Subnets[0].VpcId' --output text --region ${REGION})
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids ${VPC_ID} --query 'Vpcs[0].CidrBlock' --output text --region ${REGION})

echo Detected VPC ID: ${VPC_ID} with CIDR range of ${VPC_CIDR}.

echo Deploying Chaos Gateway to ${NUM_SUBNETS} subnets: "${SUBNETS}".
aws cloudformation create-stack \
    --template-body file://transparent-proxy.yaml \
    --stack-name chaos-gateway \
    --parameters ParameterKey=PublicSubnets,ParameterValue="${SUBNETS}" ParameterKey=InstanceCount,ParameterValue=${NUM_SUBNETS} ParameterKey=VPC,ParameterValue=${VPC_ID} ParameterKey=VPCCidr,ParameterValue=${VPC_CIDR} \
    --capabilities CAPABILITY_IAM \
    --region ${REGION}

echo Waiting for stack to complete deploying...
aws cloudformation wait stack-create-complete --stack-name chaos-gateway --region ${REGION}

echo Chaos Gateway Configuration S3 bucket: s3://$(aws cloudformation describe-stacks --stack-name chaos-gateway --query 'Stacks[].Outputs[?OutputKey==`ConfigurationBucket`].OutputValue' --output text)

echo CHAOS_GW_SUBNETS='(' "${ARGV[*]}" ')' > chaos-gateway-subnets.sh
