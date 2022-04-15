Based on the blog post and CFN from https://aws.amazon.com/blogs/security/how-to-add-dns-filtering-to-your-nat-instance-with-squid/

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