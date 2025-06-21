#!/usr/bin/env bash

set -e
set -x

# this is getting very meta, but how do I avoid the "it works on my machine" problem




# do-nothing script for installation testing

# destroy to start
virsh destroy protonpack || true
virsh undefine protonpack --remove-all-storage || true


# do update 

# turned off auto console to avoid needing to hit ctrl+] and wait for completion
# https://www.reddit.com/r/kvm/comments/1b24572/virtinstall_with_import_still_hangs_with_waiting/
time sudo virt-install --name protonpack --memory 4096 --vcpu 2 --graphics vnc --osinfo ubuntu24.04 --disk size=100,backing_store=/var/lib/libvirt/iso/noble-server-cloudimg-amd64.img,bus=virtio --cloud-init user-data=scripts/user-data.yaml --noreboot --noautoconsole

# do nothing: send ctrl+] and you'll expect 
# "Domain creation completed."

#https://www.reddit.com/r/linuxadmin/comments/5gzdtk/properly_exiting_virtinstall/


# do nothing: grep root password
#PASS=J2lHiEj3jO4gb1lM

# do nothing: grep ip address
#[   15.038761] cloud-init[829]: ci-info: | enp1s0 | True |       192.168.122.12       | 255.255.255.0 | global | 52:54:00:44:49:9b |
#read -p "Enter ip from ci-info above: " IP

IP=""
# todo: add timeout
while [ ${#IP} -le 7 ]; do  # Loop while the length of 'result' is less than or equal to 7
  IP=$(virsh domifaddr protonpack | sed -n '3p' | tr -s ' '| cut -d " " -f 5 | cut -d "/" -f 1)
  sleep 0.5
done


echo "IP is $IP"


# impressively fast!

# we are racing the install.sh script

# todo: add timeout
# login and wait till cloud-init is completely done:
# maybe wait for cloud-init.target?
SUCCESS=" "
# Loop until we see success
while [[ "$SUCCESS" != *"SUCCESS: running modules for final"* ]]; do
    SUCCESS=$(ssh -o StrictHostKeyChecking=no proton@$IP "sudo cat /var/log/cloud-init.log | grep 'SUCCESS: running modules for final'") || true
    sleep 0.5
done

echo "cloud-init completion detected"

#Run script for install.sh

# no need with ssh key: virsh console protonpack

# setup ssh
ssh -o StrictHostKeyChecking=no proton@$IP "ssh-keygen -t ed25519 -N '' -f /home/proton/.ssh/ed_25519"
# host should grab ed_25519.pub
#https://superuser.com/questions/429954/command-to-remove-a-ssh-authorized-key-on-server
temp_file=$(mktemp)
grep -v "proton@ubuntu" ~/.ssh/authorized_keys > $temp_file
cat $temp_file > ~/.ssh/authorized_keys && rm $temp_file
ssh -o StrictHostKeyChecking=no proton@$IP cat /home/proton/.ssh/ed_25519.pub >> ~/.ssh/authorized_keys

ssh -o StrictHostKeyChecking=no proton@$IP "wget -q -O - https://raw.githubusercontent.com/poleguy/protonpack/master/install.sh | bash"
# do-nothing: accept fingerprint

read -p "ARe you done?: " status

# destroy script when completed
virsh destroy protonpack
virsh undefine protonpack --remove-all-storage
