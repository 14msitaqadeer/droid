#!/bin/bash
#This script creates networks, Vagrantfiles, interfaces files, brings up target and deploy nodes and runs playbooks.
. helpers.sh
set -e
CURRENT=`pwd`
dest_interfaces="${CURRENT}/rackspace/vagrant-rpc_target/provisioning/roles/hosts-prep/templates"
dest_vagrantfile="${CURRENT}/rackspace/vagrant-rpc_target/Vagrantfile"
networknamelist_rpc=('droid_mgmt')
network_ip_rpc=()
splitted_ip=()
no_of_rpc_controllers=""
no_of_rpc_computes=""
networkmask_rpc=()
infranodesip_rpc=()
computenodesip_rpc=()
deploynodeip=""
rpc_controller_vm_name="infra"
rpc_compute_vm_name="compute"
rpc_deploy_vm_name="deploy"
rpc_ram="8192"
rpc_cpu="6"

# Creates Networks in Libvirt, Vagrantfiles for every VM to boot and interfaces files, to create bridges and setting appropriate IPz
function rackspace_setup() {
 prepare_vagrantfile_rpc
 read_num "Enter number of Controller nodes (1 OR 3)" no_of_rpc_controllers
 read_num "Enter number of compute nodes" no_of_rpc_computes
#create Networks
 for i in ${networknamelist_rpc[@]} ; do
   default_mask="255.255.255.0"
   read_ip "Enter IP for bridge interface of ${i} Network(e.g 192.168.100.1)" network_ip
   read -p "Enter Subnet Mask for ${i} Network(default 255.255.255.0):" net_mask
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
   network_ip_rpc+=($network_ip)
   networkmask_rpc+=($net_mask)
   network_ip=""
   net_mask=""
   sleep 1
 done
 #echo "${networknamelist_rpc[1]}-nic" > tmp
 #echo "${networknamelist_rpc[1]}" >> tmp
 #for i in $(cat tmp); do sudo ifconfig $i mtu 1580; echo "MTU set for $i"; done
 #echo "MTU set all"
 #sudo rm -rf tmp
 split_octet network_ip_rpc[@]
 splitted_ip[3]=$((${splitted_ip[3]}+20))
 #splitted_ip[7]=$((${splitted_ip[7]}+20))

#create Vagrantfile for controllers
   cat >> ${dest_vagrantfile} <<DELIM__
  (1..${no_of_rpc_controllers}).each do |i|
  config.vm.define "${rpc_controller_vm_name}#{i}" do |${rpc_controller_vm_name}|
    ${rpc_controller_vm_name}.vm.hostname = "${rpc_controller_vm_name}#{i}"
    ${rpc_controller_vm_name}.vm.provision "shell", inline: \$script
    # eth1
    ${rpc_controller_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))", libvirt__network_name: '${networknamelist_rpc[0]}'

    ${rpc_controller_vm_name}.vm.provider "libvirt" do |v|
        v.memory = $rpc_ram
        v.cpus = $rpc_cpu
        v.nested = true
        v.volume_cache = 'none'
    end
    ${rpc_controller_vm_name}.vm.provision "ansible" do |ansible|
        ansible.extra_vars = { ansible_ssh_user: 'vagrant' }
        ansible.playbook = "provisioning/base.yml"
        ansible.verbose = 'v'
    end
    ${rpc_controller_vm_name}.vm.provision "shell", inline: "sudo reboot"
    end
  end
DELIM__

#Create Interfaces Files for controller nodes
 for ((i=1; i<=${no_of_rpc_controllers}; i++)) ; do
   rnum=$(( $RANDOM % 10 + 51 ))
   infranodesip_rpc+=("${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))")
   cat > ${dest_interfaces}/infra${i}_interfaces <<EOF
#VAGRANT-BEGIN
auto lo
iface lo inet loopback

auto br-vxlan
iface br-vxlan inet static
      address 192.168.167.${rnum}
      netmask 255.255.255.0
      bridge_ports none

#auto eth2
#iface eth2 inet static
#      address ${splitted_ip[4]}.${splitted_ip[5]}.${splitted_ip[6]}.$((${splitted_ip[7]}+${i}))
#      netmask ${networkmask_rpc[1]}
#      mtu 1580

iface eth1 inet manual
auto br-mgmt
iface br-mgmt inet static
      address ${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))
      netmask ${networkmask_rpc[0]}
      gateway ${network_ip_rpc[0]}
      dns-nameservers 8.8.8.8
      bridge_ports eth1

auto br-vlan
iface br-vlan inet manual
      bridge_ports none

auto br-storage
iface br-storage inet static
      address 192.168.168.${rnum}
      netmask 255.255.255.0
      bridge_ports none
#VAGRANT-END
EOF
 done
 splitted_ip[3]=$((${splitted_ip[3]}+5))
 #splitted_ip[7]=$((${splitted_ip[7]}+5))

#create Vagrantfile for compute nodes
 cat >> ${dest_vagrantfile} <<DELIM__
  (1..${no_of_rpc_computes}).each do |i|
  config.vm.define "${rpc_compute_vm_name}#{i}" do |${rpc_compute_vm_name}|
    ${rpc_compute_vm_name}.vm.hostname = "${rpc_compute_vm_name}#{i}"
    ${rpc_compute_vm_name}.vm.provision "shell", inline: \$script
    # eth1
    ${rpc_compute_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))", libvirt__network_name: '${networknamelist_rpc[0]}'

    ${rpc_compute_vm_name}.vm.provider "libvirt" do |v|
        v.memory = $rpc_ram
        v.cpus = $rpc_cpu
        v.nested = true
        v.volume_cache = 'none'
    end
    ${rpc_compute_vm_name}.vm.provision "ansible" do |ansible|
        ansible.extra_vars = { ansible_ssh_user: 'vagrant' }
        ansible.playbook = "provisioning/base.yml"
        ansible.verbose = 'v'
    end
    ${rpc_compute_vm_name}.vm.provision "shell", inline: "sudo reboot"
    end
  end
DELIM__

#create Interfaces files for compute nodes
 for ((i=1; i<=${no_of_rpc_computes}; i++)) ; do
   rnum=$(( $RANDOM % 10 + 51 ))
   computenodesip_rpc+=("${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))")
   cat > ${dest_interfaces}/compute${i}_interfaces <<EOF
#VAGRANT-BEGIN
auto lo
iface lo inet loopback

auto br-vxlan
iface br-vxlan inet static
      address 192.168.167.${rnum}
      netmask 255.255.255.0
      bridge_ports none

#auto eth2
#iface eth2 inet static
#      address ${splitted_ip[4]}.${splitted_ip[5]}.${splitted_ip[6]}.$((${splitted_ip[7]}+${i}))
#      netmask ${networkmask_rpc[1]}
#      mtu 1580

iface eth1 inet manual
auto br-mgmt
iface br-mgmt inet static
      address ${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))
      netmask ${networkmask_rpc[0]}
      gateway ${network_ip_rpc[0]}
      dns-nameservers 8.8.8.8
      bridge_ports eth1

auto br-vlan
iface br-vlan inet manual
      bridge_ports none

auto br-storage
iface br-storage inet static
      address 192.168.168.${rnum}
      netmask 255.255.255.0
      bridge_ports none
#VAGRANT-END
EOF
 done
 #splitted_ip[3]=$((${splitted_ip[3]}+5))
 #splitted_ip[7]=$((${splitted_ip[7]}+5))

echo 'end' >> ${dest_vagrantfile}
}

#Creates the vagrantfile and interface file for deploy node
function prepare_deploy() {
  split_octet network_ip_rpc[@]
  cat >> ${CURRENT}/rackspace/vagrant-rpc_deploy/Vagrantfile <<DELIM__
  # Begin ${rpc_deploy_vm_name}
  config.vm.define "${rpc_deploy_vm_name}" do |${rpc_deploy_vm_name}|
    ${rpc_deploy_vm_name}.vm.hostname = "${rpc_deploy_vm_name}"
    ${rpc_deploy_vm_name}.vm.provision "shell", inline: \$script
    # eth1
    ${rpc_deploy_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+1))", libvirt__network_name: '${networknamelist_rpc[0]}'

    ${rpc_deploy_vm_name}.vm.provider "libvirt" do |v|
        v.memory = $rpc_ram
        v.cpus = $rpc_cpu
        v.nested = true
        v.volume_cache = 'none'
    end
    ${rpc_deploy_vm_name}.vm.provision "ansible" do |ansible|
        ansible.extra_vars = { ansible_ssh_user: 'vagrant' }
        ansible.playbook = "provisioning/base.yml"
        ansible.verbose = 'v'
    ${rpc_deploy_vm_name}.vm.provision "shell", inline: "sudo reboot"
    end
  end
# End ${rpc_deploy_vm_name}
end
DELIM__
  deploynodeip="${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+1))"
  cat > ${CURRENT}/rackspace/vagrant-rpc_deploy/provisioning/roles/hosts-prep/templates/deploy_interfaces <<EOF
#VAGRANT-BEGIN
# The contents below are automatically generated by Vagrant. Do not modify.
auto br-vxlan
iface br-vxlan inet manual
      bridge_ports none

iface eth1 inet manual
auto br-mgmt
iface br-mgmt inet static
      address ${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+1))
      netmask ${networkmask_rpc[0]}
      gateway ${network_ip_rpc[0]}
      dns-nameservers 8.8.8.8
      bridge_ports eth1

auto br-vlan
iface br-vlan inet manual
      bridge_ports none

auto br-storage
iface br-storage inet manual
      address 192.168.168.130
      netmask 255.255.255.0
      bridge_ports none
#VAGRANT-END
EOF
}

#Prepares vagrant file
function prepare_vagrantfile_rpc() {
cat > ${dest_vagrantfile} <<DELIM__
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
VAGRANTFILE_API_VERSION = "2"
\$script = <<SCRIPT
rm -f /etc/resolv.conf
cat << EOF >> /etc/resolv.conf
nameserver 8.8.8.8
EOF
SCRIPT
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntuserver64"
  # Turn off shared folders
  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true
DELIM__
 VAGRANTFILE_DEPLOY_PATH=${CURRENT}/rackspace/vagrant-rpc_deploy/Vagrantfile
cat > ${VAGRANTFILE_DEPLOY_PATH} <<DELIM__
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
VAGRANTFILE_API_VERSION = "2"
\$script = <<SCRIPT
rm -f /etc/resolv.conf
cat << EOF >> /etc/resolv.conf
nameserver 8.8.8.8
EOF
SCRIPT
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntuserver64"
  # Turn off shared folders
  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true
DELIM__
}

#Prerequisites for vagrant environment
function vagrant_up_rpc() {
pushd ${CURRENT}/rackspace/vagrant-rpc_target/
 vagrant box add ubuntuserver64 ${CURRENT}/ubuntuserver64.box 2>/dev/null || true
 vagrant up
popd
pushd ${CURRENT}/rackspace/vagrant-rpc_deploy/
 vagrant up
popd
 # Prints POD info(IPz)
  for ((i=1; i<=$no_of_rpc_controllers; i++)) ; do
    echo "${rpc_controller_vm_name}${i} Management    IP=${infranodesip_rpc[${i}-1]}"
  done
  for ((i=1; i<=$no_of_rpc_computes; i++)) ; do
    echo "${rpc_compute_vm_name}${i} Management  IP=${computenodesip_rpc[${i}-1]}"
  done
  echo "${rpc_deploy_vm_name} Node Management    IP=${deploynodeip}"
}
#install_libvirt
#install_packages
#rackspace_setup
#prepare_deploy
#vagrant_up_rpc
#exit 0
