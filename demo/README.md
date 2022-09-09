# EC2 Chaos Proxy Demonstration

The following demonstration will deploy an AWS VPC into your AWS account along with 2 EC2 instances that have a Redis server and a Redis client installed.  You can then use the README guide for the EC2-Chaos-Proxy project to test how the Chaos Proxy manipulates and impedes communication between the Redis client and the Redis server.

## Prerequisites
1. An AWS account for which you have the permissions to create EC2 instances, a VPC, network resources (routing table, security groups), and IAM roles.
1. Terraform v0.12 or greater
1. A Bash environment to run the scripts

## To start the demo
1. The demonstration is captured as Terraform.  To launch the Terraform stack first initialize Terraform.
    `terraform init`
1. Then deploy the Terraform template.
    `terraform apply`
1. The Terraform will output the subnet IDs for the public subnets.
1. Use the public subnet IDs to deploy the EC2 Chaos Proxy per the project README
1. Using AWS Systems Manager connect to the Redis Client EC2 instance
1. Using AWS Systems Manager connect to the Redis Server EC2 instance
1. From the Redis Client EC2 instance you can establish a Redis socket connection to the Redis server
    `redis-cli -h <IP or Hostname of Redis server>
1. Set and get some values from Redis
    ```
    set abc 123
    set def xyz
    get abc
    get def
    ```
1. Now follow the project README to download the Chaos Proxy configuration and update the tcconfig.json to add 1000 milliseconds of delay to network traffic.  Be sure and specify the CIDR range for the subnet which contains the Redis server EC2 instance.
1. To force the Redis client traffic through the proxy you will want to update the security groups for the Chaos Proxy and for the Redis instances to allow communication between the Chaos proxies and the Redis instances.
1. Using the project README you can now affect the subnet which contains the Redis client.
1. When the script completes you can call `get abc` and notice the 1 second delay reflected in the Redis output.
1. To disable the traffic redirect call the unaffect shell script.
