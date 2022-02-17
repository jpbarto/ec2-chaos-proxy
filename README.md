Based on the blog post and CFN from https://aws.amazon.com/blogs/security/how-to-add-dns-filtering-to-your-nat-instance-with-squid/

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