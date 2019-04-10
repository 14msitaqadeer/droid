#!/bin/bash
#This script creates Vagrantfiles and Pxe-boots VMs in their appropriate networks.
. helpers.sh
set -e
CURRENT=`pwd`
network_ip_mos=()
splitted_ip=()
network_namelist_mos=('PXE' 'Storage' 'External')
no_of_mos_controllers=""
no_of_mos_computes=""
mos_controller_vm_name="controller"
mos_compute_vm_name="compute"
mos_ram="8192"
mos_cpu="6"
mos_disk="60G"

#prepare_vagrantfile_mos
function prepare_vagrantfile_mos() {
 cat > ${CURRENT}/mirantis/vagrant-mos/Vagrantfile <<DELIM__
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
DELIM__
}

#Asks for cluster info and populate Vagrantfile accordingly
#Usage mos_setup
function mos_setup() {
 prepare_vagrantfile_mos
 read_num "Enter number of Controller nodes (1 OR 3)" no_of_mos_controllers
 read_num "Enter number of compute nodes" no_of_mos_computes
 for i in ${network_namelist_mos[@]} ; do
   read_ip "Enter any IP from "${i}" Network(e.g X.X.X.10)" networks_ip
   network_ip_mos+=(${networks_ip})
   networks_ip=""
 done
 split_octet network_ip_mos[@]
 prepare_vagrantfile_mos
 rnum=$(( $RANDOM % 50 + 1 ))
#Create Vagrantfile for controller node/s
   cat >> ${CURRENT}/mirantis/vagrant-mos/Vagrantfile <<DELIM__
  (1..${no_of_mos_controllers}).each do |i|
  config.vm.define "${mos_controller_vm_name}#{i}" do |${mos_controller_vm_name}|
    ${mos_controller_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${rnum}))"
    ${mos_controller_vm_name}.vm.network "private_network", ip: "${splitted_ip[4]}.${splitted_ip[5]}.${splitted_ip[6]}.$((${splitted_ip[7]}+${rnum}))"
    ${mos_controller_vm_name}.vm.network "private_network", ip: "${splitted_ip[8]}.${splitted_ip[9]}.${splitted_ip[10]}.$((${splitted_ip[12]}+${rnum}))"
    ${mos_controller_vm_name}.vm.provider :libvirt do |domain|
      domain.storage :file, :size => '$mos_disk', :type => 'qcow2'
      domain.boot 'hd'
      domain.boot 'network'
      domain.memory = $mos_ram
      domain.cpus = $mos_cpu
      domain.nested = true
      domain.volume_cache = 'none'
      end
    end
  end
DELIM__

# Create Vagrantfile for compute node/s
   cat >> ${CURRENT}/mirantis/vagrant-mos/Vagrantfile <<DELIM__
  (1..${no_of_mos_computes}).each do |i|
  config.vm.define "${mos_compute_vm_name}#{i}" do |${mos_compute_vm_name}|
    ${mos_compute_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${rnum}))"
    ${mos_compute_vm_name}.vm.network "private_network", ip: "${splitted_ip[4]}.${splitted_ip[5]}.${splitted_ip[6]}.$((${splitted_ip[7]}+${rnum}))"
    ${mos_compute_vm_name}.vm.network "private_network", ip: "${splitted_ip[8]}.${splitted_ip[9]}.${splitted_ip[10]}.$((${splitted_ip[11]}+${rnum}))"
    ${mos_compute_vm_name}.vm.provider :libvirt do |domain|
      domain.storage :file, :size => '$mos_disk', :type => 'qcow2'
      domain.boot 'hd'
      domain.boot 'network'
      domain.memory = $mos_ram
      domain.cpus = $mos_cpu
      domain.nested = true
      domain.volume_cache = 'none'
      end
    end
  end
DELIM__

 echo 'end' >> ${CURRENT}/mirantis/vagrant-mos/Vagrantfile
}

#Usage: vagrant_up_mos
function vagrant_up_mos(){
pushd ${CURRENT}/mirantis/vagrant-mos/
 vagrant up
popd
#Detach Default Interface
  for ((i=1; i<=$no_of_mos_controllers; i++)) ; do
    mac=$(sudo virsh domiflist vagrant-mos_${mos_controller_vm_name}${i} | grep vagrant-libvirt | awk '{print $5}')
    sudo virsh detach-interface --domain vagrant-mos_${mos_controller_vm_name}${i} --type network --mac $mac --persistent
  done
  for ((i=1; i<=$no_of_mos_computes; i++)) ; do
    mac=$(sudo virsh domiflist vagrant-mos_${mos_compute_vm_name}${i} | grep vagrant-libvirt | awk '{print $5}')
    sudo virsh detach-interface --domain vagrant-mos_${mos_compute_vm_name}${i} --type network --mac $mac --persistent
  done
 echo "Waiting for all Virtual Machines to finish bootstrap..."
 echo "Please correspond to FUEL UI for discovered nodes."
}
#install_libvirt
#install_packages
#mos_setup
#vagrant_up_mos
#exit 0
