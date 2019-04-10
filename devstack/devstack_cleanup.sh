#!/bin/bash
#This script will destroy all VMs and networks created by setup script.
CURRENT=`pwd`
networknamelist_dev=('dev_mgmt')

pushd $CURRENT/vagrant-devstack/
sudo vagrant destroy
popd

for i in ${networknamelist_dev[@]} ; do
  sudo virsh net-undefine ${i}
  sudo virsh net-destroy ${i}
done

echo -e "All Virtual Machines Created by Vagrant are destroyed. \nPlease remove manually created VMs if Any."
