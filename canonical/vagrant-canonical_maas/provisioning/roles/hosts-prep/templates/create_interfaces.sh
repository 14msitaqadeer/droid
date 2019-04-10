#!/bin/bash
#This Script will create interfaces in maas controller
uuid=$(maas maas-cli node-groups list | jq '.[] | select(.cluster_name=="Cluster master")' | jq .uuid | sed 's/"//g')
#eth1 mgmt
maas maas-cli node-group-interface update $uuid eth1 management=2 ip_range_low=192.168.10.50 ip_range_high=192.168.10.100 router_ip=192.168.10.1 static_ip_range_low=192.168.10.200 static_ip_range_high=192.168.10.230
