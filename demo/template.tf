provider "aws" {}

data "aws_region" "current" {}

resource "random_string" "stack_id" {
  length  = 8
  upper   = true
  lower   = false
  numeric = false
  special = false
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc-${random_string.stack_id.result}"
  cidr = "10.0.0.0/16"

  azs              = ["${data.aws_region.current.name}a", "${data.aws_region.current.name}b", "${data.aws_region.current.name}c"]
  database_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
    StackId     = random_string.stack_id.result
  }
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

resource "aws_iam_instance_profile" "ec2_inst_profile" {
  name = "demo_redis_profile"
  role = aws_iam_role.ec2_inst_role.name
}

resource "aws_iam_role" "ec2_inst_role" {
  name = "demo_redis_role"
  path = "/"

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"]

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

module "redis_client" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  name    = "redis-client"

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  monitoring             = false
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.ec2_inst_profile.id

  user_data = <<EOL
#!/usr/bin/env bash
apt update
apt -y install redis-tools
  EOL

  tags = {
    Terraform   = "true"
    Environment = "dev"
    StackId     = random_string.stack_id.result
  }
}

module "redis_server" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  name    = "redis-server"

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  monitoring             = false
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[1]
  iam_instance_profile   = aws_iam_instance_profile.ec2_inst_profile.id

  user_data = <<EOL
#!/usr/bin/env bash
apt update
apt -y install redis-server
sed -ie 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
systemctl restart redis
  EOL

  tags = {
    Terraform   = "true"
    Environment = "dev"
    StackId     = random_string.stack_id.result
  }
}
