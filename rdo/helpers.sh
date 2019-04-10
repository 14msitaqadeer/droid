#!/bin/bash
set -e

# regular expression for IP address
IP_REGEX="(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"

#### set of functions for reading formatted input ####
# read_raw message destination_variable_name regexp failure_message [default]
#
# If the destination variable is non-empty, its value will be matched
# against the regexp and, in case of success, the user will not be
# prompted at all.
function read_raw() {
  eval "local=\$${2}"
  if [[ -n "$local" && "$local" =~ $3 ]]; then
    ## the value stored in the destination variable is already OK
    echo "Using provided value [${local}] for: $1"
    return 0
  fi

  if [[ $# -eq 5 ]]; then
    echo -n "${1} (default [${5}])"
    dfl="$5"
  else
    echo -n "${1}"
    dfl=""
  fi

  while true; do
    local=""
    echo -n ": "
    read local
    [[ $local == "" ]] && local="$dfl"
    if [[ "$local" =~ $3 ]]; then
      break
    fi
    echo "  Please try again.  [${local}] is not a valid value: $4"
  done
  eval $2="\"$local\""
}

function read_ip() {
  if [[ $# -eq 3 ]]; then
    read_raw "$1" "$2" "^$IP_REGEX$" "must be an IP address" "$3"
  else
    read_raw "$1" "$2" "^$IP_REGEX$" "must be an IP address"
  fi
}

function read_num() {
  if [[ $# -eq 3 ]]; then
    read_raw "$1" "$2" "^[0-9]+$" "must use digits only" "$3"
  else
    read_raw "$1" "$2" "^[0-9]+$" "must use digits only"
  fi
}

function read_nonempty() {
  if [[ $# -eq 3 ]]; then
    read_raw "$1" "$2" "[^ ]+" "must be non-empty" "$3"
  else
    read_raw "$1" "$2" "[^ ]+" "must be non-empty"
  fi
}

function read_yesno() {
  if [[ $# -eq 3 ]]; then
    read_raw "$1" "$2" "^(yes|no|y|n)$" "type 'yes' or 'no'" "$3"
  else
    read_raw "$1" "$2" "^(yes|no|y|n)$" "type 'yes' or 'no'"
  fi

  # Normalize input to "yes" or "no".
  eval "inp=\$${2}"
  if [[ "$inp" == "y" ]]; then
    eval $2='"yes"'
  elif [[ "$inp" == "n" ]]; then
    eval $2='"no"'
  fi
}

#check and install Libvirt
function install_libvirt() {
  if ! rpm --verify virt-manager 2>/dev/null;then
    echo "Installing Libvirt..."
    yum install kvm qemu virt-viewer virt-manager libvirt libvirt-python python-virtinst -y
  fi
}
#installs some required packages and plugins
function install_packages(){
  if ! rpm --verify vagrant 2>/dev/null;then
    wget https://releases.hashicorp.com/vagrant/1.8.1/vagrant_1.8.1_x86_64.rpm
    rpm -Uvh vagrant_1.8.1_x86_64.rpm
    yum install libxslt-devel libxml2-devel libvirt-devel libguestfs-tools-c ruby-devel -y
    vagrant plugin install vagrant-libvirt
    vagrant plugin install --plugin-version 0.0.3 fog-libvirt
    echo "Packages Installed"
  else
    echo "Packages Already installed"
  fi
}

function split_octet() {
splitted_ip=()
declare -a ip_list=("${!1}")
for ((i=0; i<=${#ip_list[@]}; i++)); do
splitted_ip+=($(echo ${ip_list[${i}]} | tr "." " " | awk '{ print $1 }'))
splitted_ip+=($(echo ${ip_list[${i}]} | tr "." " " | awk '{ print $2 }'))
splitted_ip+=($(echo ${ip_list[${i}]} | tr "." " " | awk '{ print $3 }'))
splitted_ip+=($(echo ${ip_list[${i}]} | tr "." " " | awk '{ print $4 }'))
done
}
