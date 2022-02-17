Based on the blog post and CFN from https://aws.amazon.com/blogs/security/how-to-add-dns-filtering-to-your-nat-instance-with-squid/

# Use Cases

The EC2 Chaos Proxy creates a NAT instance combined with a transparent HTTP proxy.  This allows VPC-based resources to have their traffic routed through the gateway where it can be manipulated to simulate different types of failures.

1. HTTP/S Blocking
As a transparent network proxy running the Squid proxy software you have the ability to prevent communication with HTTP/S endpoints through the use of a deny list configured with the Squid proxy.  The transparent proxy will intercept HTTP / HTTPS requests and Squid proxy will deny requests so specified endpoints.

1. TCP Disruption
As a NAT instance the gateway can intercept TCP / UDP traffic and with the help of `tc` delay, deny, or otherwise mangle packets.  This enables a user to simulate packet loss on the network, latency on the network, or similar failures.

# Assumptions
1. For 2 target resources to be affected they must communicate between subnets.  If 2 target resources are in the same subnet their traffic will not be forced through the gateway.

# Usage

To launch the transparent chaos proxy use the deploy-gateway.sh script providing it with the subnets which should host the gateways:
```
./deploy-gateway.sh subnet-123abc subnet-456def subnet-987xyz
```

Once deployed the gateways will poll an S3 bucket for any configuration changes to the Squid proxy, the proxy's whitelist, or the tc settings.  This can be found in the output of the deploy command.

To route traffic from a subnet through the gateway use the following command:
```
./fail-subnet.sh subnet-123abc
```

To remove the reroute of traffic, to un-fail the subnet, use the restoration command provided by the previous command:
```
./restore-subnet.sh subnet-123abc rtb-123def
```