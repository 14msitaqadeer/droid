#!/bin/bash
#This script will destroy all VMs and networks created by setup script.
CURRENT=`pwd`

pushd ${CURRENT}/vagrant-mos/
sudo vagrant destroy
popd
echo -e "All Virtual Machines Created by Vagrant are destroyed. \nPlease remove manually created VMs if Any."
