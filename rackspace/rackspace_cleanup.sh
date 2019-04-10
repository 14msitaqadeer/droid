#!/bin/bash
#This script will destroy all VMs and networks created by setup script.
CURRENT=`pwd`
networknamelist_rpc=('droid_mgmt')

pushd $CURRENT/vagrant-rpc_target/
sudo vagrant destroy
popd
pushd $CURRENT/vagrant-rpc_deploy/
sudo vagrant destroy
popd

for i in ${networknamelist_rpc[@]} ; do
  sudo virsh net-undefine ${i}
  sudo virsh net-destroy ${i}
done

echo -e "All Virtual Machines Created by Vagrant are destroyed. \nPlease remove manually created VMs if Any."
