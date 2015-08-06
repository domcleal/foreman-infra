#!/bin/bash -xe

for h in $(cat hosts); do
  sshhost="ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@${h}"
  $sshhost "rpm -Uvh https://dl.bintray.com/mitchellh/vagrant/vagrant_1.7.4_x86_64.rpm"
  $sshhost "yum -y install libvirt libvirt-devel qemu-kvm gcc make rsync"
  $sshhost "service libvirt start"
  $sshhost "vagrant plugin install vagrant-libvirt"

  # Copy up the working directory so Vagrantfiles etc are present on the remote host
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -rp * root@${h}:
done
