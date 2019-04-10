#!/bin/bash
#This scripts creates networks, Vagrantfile, brings up MAAS controller VM and runs ansible playbooks in it.
. helpers.sh
CURRENT=`pwd`
set -e
dest_interfaces_maas="${CURRENT}/canonical/vagrant-canonical_maas/provisioning/roles/hosts-prep/templates"
dest_vagrantfile_nodes="${CURRENT}/canonical/vagrant-canonical_nodes/Vagrantfile"
dest_vagrantfile_maas="${CURRENT}/canonical/vagrant-canonical_maas/Vagrantfile"
networknamelist_maas=('droid_mgmt')
network_ip_maas=()
splitted_ip=()
networkmask_mass=()
maasnodeip=""
infra_ip=""
infra_pass=""
controllers_maclist_maas=()
computes_maclist_maas=()
juju_bootstrap_mac=""
no_of_maas_controllers=""
no_of_maas_computes=""
canonical_controller_vm_name="controller"
canonical_compute_vm_name="compute"
maas_node_vm_name="maas"
bootstrap_vm_name="bootstrap"
#Target Nodes specs
maas_node_ram="8192"
maas_node_cpu="4"
maas_node_disk="50G" #Storage Size in GB
#MAAS Controller Specs
maas_ram="8192"
maas_cpu="4"

#Function: Prepares intial Vagrantfile
#Usage: prepare_vagrantfile_nodes
function prepare_vagrantfile_nodes() {
 rnum=$(( $RANDOM % 20 + 1 ))
 rmac=$(perl -e 'printf "00:16:3E:%02X:%02X:%02X\n", rand 0xFF, rand 0xFF, rand 0xFF')
 cat > ${dest_vagrantfile_nodes} <<DELIM__
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  #Begin ${bootstrap_vm_name}
  config.vm.define :${bootstrap_vm_name} do |${bootstrap_vm_name}|
    # eth1
    ${bootstrap_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${rnum}))", libvirt__network_name: '${networknamelist_maas[0]}', mac: "${rmac}"

    ${bootstrap_vm_name}.vm.provider :libvirt do |domain|
      domain.storage :file, :size => '$maas_node_disk', :type => 'qcow2'
      domain.boot 'hd'
      domain.boot 'network'
      domain.memory = $maas_node_ram
      domain.cpus = $maas_node_cpu
      domain.nested = true
      domain.volume_cache = 'none'
    end
  end
  # End ${bootstrap_vm_name}
DELIM__
 echo "Initial Vagrantfile for nodes created"
 juju_bootstrap_mac="${rmac}"
}

#Function Creates required networks
#Usage: canonical_setup
function canonical_setup() {
 read_ip "Enter IP of infra Host" infra_ip
 read_nonempty "Enter Password of infra Host" infra_pass
 read_num "Enter number of Controller nodes (1 OR 3)" no_of_maas_controllers
 read_num "Enter number of compute nodes" no_of_maas_computes
 for i in ${networknamelist_maas[@]} ; do
   default_mask="255.255.255.0"
   read_ip "Enter IP for bridge interface of ${i} Network(e.g 192.168.100.1)" network_ip
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
   if virsh net-uuid ${i} 2>/dev/null; then
     echo "Network with name ${i} already exists, Please delete it and try again."
     exit 0
   else
     sudo cp ${i}.xml /etc/libvirt/qemu/networks/
     sudo virsh net-create /etc/libvirt/qemu/networks/${i}.xml
   fi
   sudo rm  -f ${i}.xml
   network_ip_maas+=($network_ip)
   networkmask_maas+=($net_mask)
   echo "${i} Network Created"
   network_ip=""
   net_mask=""
 done
 #echo "${networknamelist_maas[1]}-nic" >> tmp
 #echo "${networknamelist_maas[1]}" >> tmp
 #for i in $(cat tmp); do sudo ifconfig $i mtu 1580; echo "MTU set for $i"; done
 #echo "MTU set all"
 #sudo rm -rf tmp
 split_octet network_ip_maas[@]
 prepare_vagrantfile_nodes

#Create Vagrantfile for controller node/s
 for ((i=1; i<=${no_of_maas_controllers}; i++)) ; do
   rnum=$(( $RANDOM % 20 + 1 ))
   rmac=$(perl -e 'printf "00:16:3E:%02X:%02X:%02X\n", rand 0xFF, rand 0xFF, rand 0xFF')
   cat >> ${dest_vagrantfile_nodes} <<DELIM__
  #Begin ${canonical_controller_vm_name}${i}
  config.vm.define :${canonical_controller_vm_name}${i} do |${canonical_controller_vm_name}${i}|
    # eth1
    ${canonical_controller_vm_name}${i}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${rnum}))", libvirt__network_name: '${networknamelist_maas[0]}', mac: "${rmac}"

    ${canonical_controller_vm_name}${i}.vm.provider :libvirt do |domain|
      domain.storage :file, :size => '$maas_node_disk', :type => 'qcow2'
      domain.boot 'hd'
      domain.boot 'network'
      domain.memory = $maas_node_ram
      domain.cpus = $maas_node_cpu
      domain.nested = true
      domain.volume_cache = 'none'
    end
  end
  # End ${canonical_controller_vm_name}${i}
DELIM__
 controllers_maclist_maas+=(${rmac})
 echo "vagrantfile for controller${i} created"
 done

#Create Vagrantfile for compute node/s
 for ((i=1; i<=${no_of_maas_computes}; i++)) ; do
   rnum=$(( $RANDOM % 20 + 1 ))
   rmac=$(perl -e 'printf "00:16:3E:%02X:%02X:%02X\n", rand 0xFF, rand 0xFF, rand 0xFF')
   cat >> ${dest_vagrantfile_nodes} <<DELIM__
  #Begin ${canonical_compute_vm_name}${i}
  config.vm.define :${canonical_compute_vm_name}${i} do |${canonical_compute_vm_name}${i}|
    # eth1
    ${canonical_compute_vm_name}${i}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+${rnum}))", libvirt__network_name: '${networknamelist_maas[0]}', mac: "${rmac}"

    ${canonical_compute_vm_name}${i}.vm.provider :libvirt do |domain|
      domain.storage :file, :size => '$maas_node_disk', :type => 'qcow2'
      domain.boot 'hd'
      domain.boot 'network'
      domain.memory = $maas_node_ram
      domain.cpus = $maas_node_cpu
      domain.nested = true
      domain.volume_cache = 'none'
    end
  end
  # End ${canonical_compute_vm_name}${i}
DELIM__
 computes_maclist_maas+=(${rmac})
 echo "vagrantfile for compute${i} created"
 done
 echo 'end' >> ${dest_vagrantfile_nodes}
}

#Function: creates Vagrantfile
#Usage: prepare_maas
function prepare_maas() {
  split_octet network_ip_maas[@]
  splitted_ip[3]=$((${splitted_ip[3]}+20))
  #splitted_ip[7]=$((${splitted_ip[7]}+20))
  cat > ${dest_vagrantfile_maas} <<DELIM__
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
  # Begin ${maas_node_vm_name}
  config.vm.define "${maas_node_vm_name}" do |${maas_node_vm_name}|
    ${maas_node_vm_name}.vm.hostname = "maas"
    ${maas_node_vm_name}.vm.provision "shell", inline: \$script
    # eth1
    ${maas_node_vm_name}.vm.network "private_network", ip: "${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+1))", libvirt__network_name: '${networknamelist_maas[0]}'
    # eth2
    ${maas_node_vm_name}.vm.provider "libvirt" do |v|
        v.memory = $maas_ram
        v.cpus = $maas_cpu
        v.nested = true
        v.volume_cache = 'none'
    end
    ${maas_node_vm_name}.vm.provision "ansible" do |ansible|
        ansible.extra_vars = { ansible_ssh_user: 'vagrant' }
        ansible.playbook = "provisioning/base.yml"
        ansible.verbose = 'v'
    ${maas_node_vm_name}.vm.provision "shell", inline: "sudo reboot"
    end
  end
# End ${maas_node_vm_name}
end
DELIM__
 echo "vagrantfile for MAAS created"
 maasnodeip="${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+1))"
 cat > ${dest_interfaces_maas}/interfaces <<EOF
#VAGRANT-BEGIN
auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
      address ${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.$((${splitted_ip[3]}+1))
      netmask ${networkmask_maas[0]}
      gateway ${network_ip_maas[0]}
      dns-nameservers 8.8.8.8

#auto eth2
#iface eth2 inet static
#      address ${splitted_ip[4]}.${splitted_ip[5]}.${splitted_ip[6]}.$((${splitted_ip[7]}+1))
#      netmask ${networkmask_maas[1]}
#      mtu 1580
#VAGRANT-END
EOF
 echo "Interfaces file for MAAS created"
 cat > $dest_interfaces_maas/create_interfaces.sh <<EOF
#!/bin/bash
#This Script will create interfaces in maas controller
uuid=\$(maas maas-cli node-groups list | jq '.[] | select(.cluster_name=="Cluster master")' | jq .uuid | sed 's/"//g')
#eth1 mgmt
maas maas-cli node-group-interface update \$uuid eth1 management=2 ip_range_low=${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.50 ip_range_high=${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.100 router_ip=${network_ip_maas[0]} static_ip_range_low=${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.200 static_ip_range_high=${splitted_ip[0]}.${splitted_ip[1]}.${splitted_ip[2]}.230
EOF
}

#Function creates a script to copy SSH key into infra host
#Usage create_script
function create_script() {
 infra_username=$(echo $HOME | cut -d/ -f3 | awk '{ print $1}')
 cat > ${CURRENT}/canonical/vagrant-canonical_maas/provisioning/roles/hosts-prep/files/ssh_copy_id.sh <<DELIM__
#!/bin/bash
#This script will copy maas superuser PUB key to infra host
 cat > /tmp/ssh_copy_id.py <<EOF
import pexpect, sys
child = pexpect.spawn("scp -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no -o UserKnownHostsFile=/dev/null /var/lib/maas/.ssh/id_rsa.pub ${infra_username}@${infra_ip}:~/.ssh/authorized_keys", logfile=sys.stdout, timeout=None)
child.expect(".*password: ")
child.sendline("${infra_pass}")
child.expect(pexpect.EOF, timeout=None)
EOF
python /tmp/ssh_copy_id.py
DELIM__
}

#Usage vagrant_up_maas
function vagrant_up_maas() {
 create_script
pushd ${CURRENT}/canonical/vagrant-canonical_maas/
 vagrant box add ubuntuserver64 ${CURRENT}/ubuntuserver64.box 2>/dev/null || true
 vagrant up
popd
 sleep 180
 echo "MAAS VM Brought Up"
pushd ${CURRENT}/canonical/vagrant-canonical_nodes/
 vagrant up
popd
 echo "Target Nodes VMs Brought Up"
 echo "MAAS Node Management/Prov    IP=${maasnodeip}"
 echo "MAAS superuser username=root"
 echo "MAAS superuser password=root"
#Prints Nodes MACs
echo "Mac address of all nodes:"
for ((i=1; i<=$no_of_maas_controllers; i++)) ; do
  echo "${canonical_controller_vm_name}${i}  Management interface MAC Address=${controllers_maclist_maas[${i}-1]}"
done
for ((i=1; i<=$no_of_maas_computes; i++)) ; do
  echo "${canonical_compute_vm_name}${i}     Management interface MAC Address=${computes_maclist_maas[${i}-1]}"
done
echo Bootstrap Node	Management interface MAC Address=${juju_bootstrap_mac}
}
#install_libvirt
#install_packages
#canonical_setup
#prepare_maas
#vagrant_up_maas
#exit 0
