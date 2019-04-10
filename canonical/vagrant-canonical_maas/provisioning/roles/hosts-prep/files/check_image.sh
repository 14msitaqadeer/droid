#!/bin/bash
#This Script will wait untill image is imported
show_message="Importing image."
uuid=$(maas maas-cli node-groups list | jq '.[] | select(.cluster_name=="Cluster master")' | jq .uuid | sed 's/"//g')
check=$(maas maas-cli boot-images read $uuid)
while [ ${#check} -eq 2 ]; do
        sleep 30
        check=$(maas maas-cli boot-images read $uuid)
	echo $show_message
        show_message="${show_message}."
done
echo "Image is imported"
