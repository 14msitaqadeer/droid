#!/bin/bash
#This script creates networks in libvirt, creates vagrantfiles for OSPD and overcloud virtual machines and finally bring them up.
. helpers.sh
set -e
CURRENT=`pwd`
network_ip_rdo=()
splitted_ip=()
networknamelist_rdo=('droid_prov' 'droid_ext')
no_of_rdo_controllers=""
no_of_rdo_computes=""
overcloudvm_name=()
controllers_maclist_rdo=()
computes_maclist_rdo=()
rdo_controller_vm_name="controller"
rdo_compute_vm_name="compute"
rdo_ospd_vm_name="ospd"
ospd_ram="8192"
ospd_cpu="6"
rdo_node_ram="8192"
rdo_node_cpu="6"
rdo_node_disk="50G"

#Function: Prepares intial Vagrantfile
#Usage: prepare_vagrantfile_rdooc
function prepare_vagrantfile_rdooc() {
 cat > ${CURRENT}/rdo/vagrant-rdo_overcloud/Vagrantfile <<DELIM__
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
DELIM__
}

#Function: Asks for no of overcloud machines and populates Vagrantfile accordingly
#Usage: rdo_setup
function rdo_setup() {
 read_num "Enter number of Controller nodes (1 OR 3)" no_of_rdo_controllers
 read_num "Enter number of compute nodes" no_of_rdo_computes
#Asks for Network IP
 for i in ${networknamelist_rdo[@]} ; do
   default_mask="255.255.255.0"
   read_ip "Enter IP for bridge interface of "${i}" Network(e.g 192.168.100.1)" network_ip
   read -p "Enter Subnet Mask for ${i} Network(Default 255.255.255.0):" net_mask
   net_mask=${net_mask:-$default_mask}
   uuid=$(uuidgen)
   rmac=$(perl -e 'printf "00:16:3E:%02X:%02X:%02X\n", rand 0xFF, rand 0xFF, rand 0xFF')
   cat > ${i}.xml <<EOF
<network>
  <name>${i}</name>
  <uuid>${uuid}</uuid>
  <forward mode='nat'/>
  <bridge name='${i}' stp='on' delay='0'/>
  <mac address='${rmac}'/>
  <ip address='${network_ip}' netmask='${net_mask}'>
  </ip>
</network>
EOF
   if virsh net-uuid ${i} 2>/dev/null;then
     echo "Network with name ${i} already exists, Please delete it and try again."
     exit 0
   else
     sudo cp ${i}.xml /etc/libvirt/qemu/networks/
     sudo virsh net-create /etc/libvirt/qemu/networks/${i}.xml
   fi
   sudo rm -f ${i}.xml
   network_ip_rdo+=(${network_ip})
   network_ip=""
   net_mask=""
   sleep 1
 done
  #echo "${networknamelist_rdo[0]}-nic" > tmp
  #echo "${networknamelist_rdo[0]}" >> tmp
  #for i in $(cat tmp); do sudo ifconfig $i mtu 1580; echo "MTU set for $i"; done
  #echo "MTU set all"
  #sudo rm -rf tmp
  split_octet network_ip_rdo[@]
  prepare_vagrantfile_rdooc

#Create Vagrantfile for controller node/s
 for ((i=1; i<=${no_of_rdo_controllers}; i++)) ; do
   rnum=$(( $RANDOM % 50 + 1 ))
   rmac=$(perl -e 'printf "00:16:3E:%02X:%02X:%02X\n", rand 0xFF, rand 0xFF, rand 0xFF')
   cat >> ${CURRENT}/rdo/vagrant-rdo_overcloud/Vagrantfile <<DELIM__
  #Begin ${rdo_controller_vm_name}${i}
  config.vm.define :${rdo_controller_vm_name}${i} do |${rdo_controller_vm_name}${i}|
    ${rdo_controller_vm_name}${i}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${rnum}))", libvirt__network_name: '${networknamelist_rdo[0]}', mac: "${rmac}"
    ${rdo_controller_vm_name}${i}.vm.provider :libvirt do |domain|
      domain.storage :file, :size => '$rdo_node_disk', :type => 'qcow2'
      domain.boot 'hd'
      domain.boot 'network'
      domain.memory = $rdo_node_ram
      domain.cpus = $rdo_node_cpu
      domain.nested = true
      domain.volume_cache = 'none'
    end
  end
  # End ${rdo_controller_vm_name}${i}

DELIM__
 overcloudvm_name+=("${rdo_controller_vm_name}${i}")
 controllers_maclist_rdo+=(${rmac})
 done

#Create Vagrantfile for compute node/s
 for ((i=1; i<=${no_of_rdo_computes}; i++)) ; do
   rnum=$(( $RANDOM % 50 + 1 ))
   rmac=$(perl -e 'printf "00:16:3E:%02X:%02X:%02X\n", rand 0xFF, rand 0xFF, rand 0xFF')
   cat >> ${CURRENT}/rdo/vagrant-rdo_overcloud/Vagrantfile <<DELIM__
  #Begin ${rdo_compute_vm_name}${i}
  config.vm.define :${rdo_compute_vm_name}${i} do |${rdo_compute_vm_name}${i}|
    ${rdo_compute_vm_name}${i}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${rnum}))", libvirt__network_name: '${networknamelist_rdo[0]}', mac: "${rmac}"
    ${rdo_compute_vm_name}${i}.vm.provider :libvirt do |domain|
      domain.storage :file, :size => '$rdo_node_disk', :type => 'qcow2'
      domain.boot 'hd'
      domain.boot 'network'
      domain.memory = $rdo_node_ram
      domain.cpus = $rdo_node_cpu
      domain.nested = true
      domain.volume_cache = 'none'
    end
  end
  # End ${rdo_compute_vm_name}${i}

DELIM__
 overcloudvm_name+=("${rdo_compute_vm_name}${i}")
 computes_maclist_rdo+=(${rmac})
 done

 echo 'end' >> ${CURRENT}/rdo/vagrant-rdo_overcloud/Vagrantfile
}

#Function: Create Vagrantfile for undercloud (OSPD)
#usage: prepare_ospd
function prepare_ospd() {
 split_octet network_ip_rdo[@]
 rnum=$(( $RANDOM % 50 + 1 ))
 cat > ${CURRENT}/rdo/vagrant-rdo_ospd/Vagrantfile <<DELIM__
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
VAGRANTFILE_API_VERSION = "2"
\$script = <<SCRIPT
hostnamectl set-hostname director.rdo.com
hostnamectl set-hostname --transient director.rdo.com
echo "nameserver 8.8.8.8" > /etc/resolv.conf
SCRIPT
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "rhelserver7"
  # Turn off shared folders
  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true
  # Begin ospd
  config.vm.define "${rdo_ospd_vm_name}" do |${rdo_ospd_vm_name}|
    ${rdo_ospd_vm_name}.vm.hostname = "director"
    ${rdo_ospd_vm_name}.vm.provision "shell", inline: \$script
    # eth1
    ${rdo_ospd_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${rnum}))", libvirt__network_name: '${networknamelist_rdo[0]}'
    # eth2
    ${rdo_ospd_vm_name}.vm.network "private_network", ip: "${splitted_ip[4]}.${splitted_ip[5]}.${splitted_ip[6]}.$((${splitted_ip[7]}+${rnum}))", libvirt__network_name: '${networknamelist_rdo[1]}'
    ${rdo_ospd_vm_name}.vm.provider "libvirt" do |v|
        v.memory = $ospd_ram
        v.cpus = $ospd_cpu
        v.nested = true
        v.volume_cache = 'none'
    end
  end
end
DELIM__
}

#Usage: vagrant_up_rdo
function vagrant_up_rdo() {
pushd ${CURRENT}/rdo/vagrant-rdo_ospd/
 vagrant box add rhelserver7 ${CURRENT}/rhelserver7.box 2>/dev/null || true
 echo "Bringing up OSPD VM..."
 vagrant up
popd
pushd ${CURRENT}/rdo/vagrant-rdo_overcloud/
 echo "Bringing up Overcloud VMs..."
 vagrant up
 echo "Shutting down Overcloud Virtual Machines"
#Shuts down all overcloud VMs
for i in ${overcloudvm_name[@]}; do
  virsh destroy vagrant-rdo_overcloud_${i}
  mac=$(sudo virsh domiflist vagrant-rdo_overcloud_${i} | grep vagrant-libvirt | awk '{print $5}')
  sudo virsh detach-interface --domain vagrant-rdo_overcloud_${i} --type network --mac $mac --config
  echo "${i} shutdown"
done
popd

# Gives overcloud MACs
echo "Mac address of all overcloud VMs:"
for ((i=1; i<=$no_of_rdo_controllers; i++)) ; do
  echo "${rdo_controller_vm_name}${i}	Provisioning interface MAC Address=${controllers_maclist_rdo[${i}-1]}"
done
for ((i=1; i<=$no_of_rdo_computes; i++)) ; do
  echo "${rdo_compute_vm_name}${i}	Provisioning interface MAC Address=${computes_maclist_rdo[${i}-1]}"
done
}
#install_libvirt
#install_packages
#rdo_setup
#prepare_ospd
#vagrant_up_rdo
#exit 0
