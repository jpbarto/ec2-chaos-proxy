# EC2 Chaos Gateway

> Based on the blog post and CFN from https://aws.amazon.com/blogs/security/how-to-add-dns-filtering-to-your-nat-instance-with-squid/

## Overview
This Cloudformation template and set of scripts deploy a set of transparent network proxies designed to allow someone to intercept and mutate network traffic in a VPC.  This is meant to support Chaos Engineering experiments within a VPC environment where the experiment needs to delay, drop, or rate limit traffic between two IP-based endpoints.  Because the proxy operates in a transparent fashion it is suitable for intercepting traffic to or from:
- EC2 instances
- VPC-bound lambda functions
- RDS databases
- Elasticache clusters
- Interface VPC endpoints
- other resources addressed through ENIs

The Squid proxy also supports denying access to URLs external to the VPC.  

Through the combination of Traffic Control and Squid Proxy you can:
- limit network bandwidth to / from a network resource
- drop a percentage of IP packets to / from a network resource
- drop ALL IP packets to / from a network resource
- delay IP packets to / from a network resource
- deny access to hostnames

For example the database traffic leaving an application in one subnet can be intercepted by the Chaos Gateway as it travels to an RDS database to simulate a network disruption between the client and the database.  The Chaos Gateway can drop 30% of the TCP packets carrying the database session to determine if the application code compensates for the traffic disruption or if alarms detect the disruption.

Much of the testing was performed using Redis where the client / server communication had 1+ seconds of delay added to the stream via the Chaos Gateway.

The Gateway relies on the route tables associated with VPC subnets so that the client and server applications do not need to be modified.  The route table will redirect traffic through the Chaos Gateway.  If the client and server are in the same subnet the traffic can still be routed through the Chaos Gateway but the local routing table of the client will need to be modified and the Gateway will need to be in the same subnet as the client and server.

# Use Cases

The EC2 Chaos Proxy creates a NAT instance combined with a transparent HTTP proxy.  This allows VPC-based resources to have their traffic routed through the gateway where it can be manipulated to simulate different types of failures.

1. HTTP/S Blocking
As a transparent network proxy running the Squid proxy software you have the ability to prevent communication with HTTP/S endpoints through the use of a deny list configured with the Squid proxy.  The transparent proxy will intercept HTTP / HTTPS requests and Squid proxy will deny requests so specified endpoints.

1. TCP Disruption
As a NAT instance the gateway can intercept TCP / UDP traffic and with the help of `tc` delay, deny, or otherwise mangle packets.  This enables a user to simulate packet loss on the network, latency on the network, or similar failures.

# Assumptions
1. The proxy relies upon AWS route tables associated with subnets to direct traffic to the chaos proxy.
1. For 2 target resources to be affected they must communicate between subnets.  If 2 target resources are in the same subnet their traffic will not be forced through the gateway.

# Usage

In the following steps your network is configured as:

Public Subnets: subnet-123abc, subnet456def, subnet987xyz

Private Subnets: subnet-abcdef, subnet-lmnopq, subnet-stuvwx

Database Subnets: subnet-123456, subnet-789012, subnet-357913

The Public Subnets have routes associated with the IGW for the VPC, the Private and Database subnets have route tables for local endpoints and a NAT Gateway.

To launch the transparent chaos proxy use the deploy-gateway.sh script providing it with the subnets which should host the gateways:
```
./deploy-gateway.sh subnet-123abc subnet-456def subnet-987xyz
```

**Note:** The `deploy-gateway.sh` script requires that the AWS CLI be configured with a default region, for example by setting the AWS_DEFAULT_REGION environment variable.

Once deployed the gateways will poll an S3 bucket for any configuration changes to the Squid proxy, the proxy's whitelist, or the tc settings.  This can be found in the output of the deploy command.

To configure the gateways to delay TCP traffic:
```
mkdir -p /tmp/chaos-gateway
cd /tmp/chaos-gateway
aws s3 sync s3://chaos-gateway-s3bucket-nrcxpwabgf7o .
cat >tc/tcconfig.json <<EOF
{
    "eth0": {
        "outgoing": {
            "dst-network=10.0.1.0/24, dst-port=6379, protocol=ip": {
                "filter_id": "800::800",
                "delay": "1.0s",
                "rate": "32Gbps"
            }
        },
        "incoming": {}
    }
}
EOF
aws s3 sync . s3://chaos-gateway-s3bucket-nrcxpwabgf7o
```


To route traffic from a subnet through the gateway use the following command:
```
./fail-subnet.sh subnet-123abc
```

To remove the reroute of traffic, to un-fail the subnet, use the restoration command provided by the previous command:
```
./restore-subnet.sh subnet-123abc rtb-123def
```

# Scenarios

## Cross-subnet scenario
To test communication between networked resources in different subnets, use the above shell scripts to modify the route tables for the subnets to force traffic through the chaos gateways.

## Intra-subnet scenario
To test communication between two networked resources in the same subnet you will need a chaos gateway deployed in the same subnet as the networked resources.  Then modify the routes on the target networked resource.  For example if a database at 10.0.2.23 is in a subnet with a database client at 10.0.2.31 with a chaos gateway deployed at 10.0.2.45 then create a route on the database client with a command like:

```
ip route add 10.0.2.23/32 via 10.0.2.45
```

The traffic from the client to the database will then be sent through the chaos gateway.  

## HTTP-based scenario
