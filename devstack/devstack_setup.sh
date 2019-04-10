#!/bin/bash
#This script creates networks, Vagrantfiles, interfaces files, brings up controller and compute nodes and runs playbooks.

set -e
CURRENT=`pwd`
dest_interfaces_dev="${CURRENT}/devstack/vagrant-devstack/provisioning/roles/hosts-prep/templates"
dest_vagrantfile_dev="${CURRENT}/devstack/vagrant-devstack/Vagrantfile"
networknamelist_dev=('dev_mgmt')
network_ip_dev=()
splitted_ip=()
no_of_dev_controllers=""
no_of_dev_computes=""
networkmask_dev=()
controllernodesip_dev=()
computenodesip_dev=()
dev_controller_vm_name="controller"
dev_compute_vm_name="compute"
dev_ram="8192"
dev_cpu="4"

#Prepares vagrant file
function prepare_vagrantfile_dev() {
cat > ${dest_vagrantfile_dev} <<DELIM__
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


# Creates Networks in Libvirt, Vagrantfiles for every VM to boot and interfaces files, to create bridges and setting appropriate IPz
function devstack_setup() {
 prepare_vagrantfile_dev
 read_num "Enter number of Controller nodes (1 OR 3)" no_of_dev_controllers
 read_num "Enter number of compute nodes" no_of_dev_computes

#create Networks
 for i in ${networknamelist_dev[@]} ; do
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
   network_ip_dev+=($network_ip)
   networkmask_dev+=($net_mask)
   network_ip=""
   net_mask=""
   sleep 1
 done

split_octet network_ip_dev[@]
 splitted_ip[3]=$((${splitted_ip[3]}+20))

#create Vagrantfile for controllers
   cat >> ${dest_vagrantfile_dev} <<DELIM__
  (1..${no_of_dev_controllers}).each do |i|
  config.vm.define "${dev_controller_vm_name}#{i}" do |${dev_controller_vm_name}|
    ${dev_controller_vm_name}.vm.hostname = "${dev_controller_vm_name}#{i}"
    ${dev_controller_vm_name}.vm.provision "shell", inline: \$script
    # eth1
    ${dev_controller_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))", libvirt__network_name: '${networknamelist_dev[0]}'

    ${dev_controller_vm_name}.vm.provider "libvirt" do |v|
        v.memory = $dev_ram
        v.cpus = $dev_cpu
        v.nested = true
        v.volume_cache = 'none'
    end
    ${dev_controller_vm_name}.vm.provision "ansible" do |ansible|
        ansible.extra_vars = { ansible_ssh_user: 'vagrant' }
        ansible.playbook = "provisioning/base.yml"
        ansible.verbose = 'v'
    end
    ${dev_controller_vm_name}.vm.provision "shell", inline: "sudo reboot"
    end
  end
DELIM__

#Create Interfaces Files for controller nodes
 for ((i=1; i<=${no_of_dev_controllers}; i++)) ; do
   controllernodesip_dev+=("${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))")
   cat > ${dest_interfaces_dev}/controller${i}_interfaces <<EOF
#VAGRANT-BEGIN
auto lo
iface lo inet loopback

auto eth1
iface eth1 inet static
      address ${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))
      netmask ${networkmask_dev[0]}
      gateway ${network_ip_dev[0]}
      dns-nameservers 8.8.8.8

#VAGRANT-END
EOF

 done
 splitted_ip[3]=$((${splitted_ip[3]}+5))

#create Vagrantfile for compute nodes
 cat >> ${dest_vagrantfile_dev} <<DELIM__
  (1..${no_of_dev_computes}).each do |i|
  config.vm.define "${dev_compute_vm_name}#{i}" do |${dev_compute_vm_name}|
    ${dev_compute_vm_name}.vm.hostname = "${dev_compute_vm_name}#{i}"
    ${dev_compute_vm_name}.vm.provision "shell", inline: \$script
    # eth1
    ${dev_compute_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))", libvirt__network_name: '${networknamelist_dev[0]}'

    ${dev_compute_vm_name}.vm.provider "libvirt" do |v|
        v.memory = $dev_ram
        v.cpus = $dev_cpu
        v.nested = true
        v.volume_cache = 'none'
    end
    ${dev_compute_vm_name}.vm.provision "ansible" do |ansible|
        ansible.extra_vars = { ansible_ssh_user: 'vagrant' }
        ansible.playbook = "provisioning/base.yml"
        ansible.verbose = 'v'
    end
    ${dev_compute_vm_name}.vm.provision "shell", inline: "sudo reboot"
    end
  end
DELIM__

#create Interfaces files for compute nodes
 for ((i=1; i<=${no_of_dev_computes}; i++)) ; do
   computenodesip_dev+=("${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))")
   cat > ${dest_interfaces_dev}/compute${i}_interfaces <<EOF
#VAGRANT-BEGIN
auto lo
iface lo inet loopback

auto eth1
iface eth1 inet static
      address ${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${i}))
      netmask ${networkmask_dev[0]}
      gateway ${network_ip_dev[0]}
      dns-nameservers 8.8.8.8

EOF
 done

echo 'end' >> ${dest_vagrantfile_dev}
}

#Prerequisites for vagrant environment
function vagrant_up_dev() {
pushd ${CURRENT}/devstack/vagrant-devstack/
 vagrant box add ubuntuserver64 ${CURRENT}/ubuntuserver64.box 2>/dev/null || true
 vagrant up
popd
 # Prints POD info(IPz)
  for ((i=1; i<=$no_of_dev_controllers; i++)) ; do
    echo "${dev_controller_vm_name}${i} Management    IP=${controllernodesip_dev[${i}-1]}"
  done
  for ((i=1; i<=$no_of_dev_computes; i++)) ; do
    echo "${dev_compute_vm_name}${i} Management  IP=${computenodesip_dev[${i}-1]}"
  done
}
