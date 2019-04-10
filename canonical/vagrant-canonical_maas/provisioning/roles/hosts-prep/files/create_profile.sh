#!/bin/bash
#This Script will create login profile from CLI and import image.
MAAS_KEY=$(sudo maas-region-admin apikey --username root)
maas login maas-cli http://127.0.0.1/MAAS/api/1.0 $MAAS_KEY
sleep 5
maas maas-cli boot-resources import
