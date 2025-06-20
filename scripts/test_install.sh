#!/usr/bin/env bash

# this is getting very meta, but how do I avoid the "it works on my machine" problem


# do-nothing script for installation testing

# do update 


time sudo virt-install --name protonpack --memory 4096 --vcpu 2 --graphics vnc --osinfo ubuntu24.04 --disk size=100,backing_store=/var/lib/libvirt/iso/noble-server-cloudimg-amd64.img,bus=virtio --cloud-init user-data=scripts/user-data.yaml

# do nothing: grep root password
#PASS=J2lHiEj3jO4gb1lM

# do nothing: grep ip address
#[   15.038761] cloud-init[829]: ci-info: | enp1s0 | True |       192.168.122.12       | 255.255.255.0 | global | 52:54:00:44:49:9b |
read -p "Enter ip from ci-info above: " IP

# do nothing: send ctrl+] and you'll expect
# Domain creation completed.

# impressively fast!

# login and set password?



#Run script for install.sh

# no need with ssh key: virsh console protonpack


ssh proton@$IP "wget -q -O - https://raw.githubusercontent.com/poleguy/protonpack/master/install.sh | bash"
# do-nothing: accept fingerprint

read -p "ARe you done?: " status

# destroy script when completed
virsh destroy protonpack
virsh undefine protonpack --remove-all-storage
