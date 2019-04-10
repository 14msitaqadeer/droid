#!/bin/bash
#This script will destroy all VMs and networks created by setup script.
CURRENT=`pwd`
networknamelist_rdo=('droid_prov' 'droid_ext')

pushd $CURRENT/vagrant-rdo_ospd/
sudo vagrant destroy
popd
pushd $CURRENT/vagrant-rdo_overcloud/
sudo vagrant destroy
popd

for i in ${networknamelist_rdo[@]} ; do
  sudo virsh net-undefine ${i}
  sudo virsh net-destroy ${i}
done

echo -e "All Virtual Machines Created by Vagrant are destroyed. \nPlease remove manually created VMs if Any."
