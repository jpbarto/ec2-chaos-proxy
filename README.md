Based on the blog post and CFN from https://aws.amazon.com/blogs/security/how-to-add-dns-filtering-to-your-nat-instance-with-squid/

To launch the transparent chaos proxy use the deploy-gateway.sh script providing it with the subnets which should host the gateways:
```
./deploy-gateway.sh subnet-123abc subnet-456def subnet-987xyz
```