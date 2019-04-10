#!/bin/bash
#This script checks if libvirt is installed, checks which distro to deploy and runs appropriate script for that distro. 

set -e

. helpers.sh
. devstack/devstack_setup.sh
. rackspace/rackspace_setup.sh
. mirantis/mos_setup.sh
. rdo/rdo_setup.sh
. canonical/canonical_setup.sh

#Function: checks for distros(which distro to deploy)
#Usage check_distro

function check_distro(){

 read_yesno "Is this a Devstack Setup(y/n)" devstack_setup
  if [ ${devstack_setup} == "yes" ] ; then
    devstack_setup
    install_libvirt
    install_packages
    vagrant_up_dev
    exit 0
  fi

  read_yesno "Is this a Rackspace Setup(y/n)" rackspace_setup
  if [ ${rackspace_setup} == "yes" ] ; then
    rackspace_setup
    prepare_deploy
    install_libvirt
    install_packages
    vagrant_up_rpc
    exit 0
  fi
  read_yesno "Is this a Mirantis Setup(y/n)" mos_setup
  if [ ${mos_setup} == "yes" ] ; then
    mos_setup
    install_libvirt
    install_packages
    vagrant_up_mos
    exit 0
  fi
  read_yesno "Is this a RDO Setup(y/n)" rdo_setup
  if [ ${rdo_setup} == "yes" ] ; then
    rdo_setup
    prepare_ospd
    install_libvirt
    install_packages
    vagrant_up_rdo
    exit 0
  fi
  read_yesno "Is this a Canonical Setup(y/n)" canonical_setup
  if [ ${canonical_setup} == "yes" ] ; then
    canonical_setup
    prepare_maas
    install_libvirt
    install_packages
    vagrant_up_maas
    exit 0
  fi
}

check_libvirt=$(dpkg -s libvirt-bin | grep Status)
if [ "${check_libvirt}" == "Status: install ok installed" ] ; then
  check_distro
else
  echo "Installing Libvirt..."
  sudo apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils -y
  sudo adduser $USER libvirtd
  sudo apt-get install virt-manager -y
  check_distro
  exit 0
fi
