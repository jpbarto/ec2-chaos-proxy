#!/usr/bin/env bash

set -e

curl https://ip-ranges.amazonaws.com/ip-ranges.json -o /tmp/aws-ip.json
for cidr in `jq '.prefixes[] | select(.service == "DYNAMODB" and .region == "eu-west-1") | .ip_prefix' /tmp/aws-ip.json`
do 
  echo going to block $cidr
done