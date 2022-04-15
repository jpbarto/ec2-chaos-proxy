[] the chaos gateway nodes need permissions at the security group level to talk to other resources.  Use the default security group for now, have the cloudformation attach the default sg to each instance.
[] the fail subnet script needs to further tailor the route table to direct traffic for the local resources to the gateway, modifying the default route directed towards local to send traffic to the gateway seems to work
[] consider adding the old route table id to the subnet as a tag so it can be restored more easily
[] add a blacklist to contrast the whitelist for the squid proxy
