#!/bin/bash -xe

if [ ${os#f} != $os ]; then
  osname=fedora
  osver=${os#f}
  osvariant=${osname}${osver}
  args="--selinux-relabel"
elif [ ${os#el} != $os ]; then
  osname=centos
  osver=${os#el}
  if [ $osver -eq 6 ]; then
    osvariant=${osname}6.5
  else
    osver=7.1
    osvariant=${osname}7.0
  fi
  args="--selinux-relabel"
elif [ ${os} = precise ]; then
  osname=ubuntu
  osver=12.04
  osvariant=${osname}${osver}
elif [ ${os} = trusty ]; then
  osname=ubuntu
  osver=14.04
  osvariant=${osname}13.04
elif [ ${os} = wheezy ]; then
  osname=debian
  osver=7
  osvariant=${osname}${osver}
elif [ ${os} = jessie ]; then
  osname=debian
  osver=8
  osvariant=${osname}7
else
  echo "unknown OS ${os}"
  exit 1
fi

h=$(head -1 hosts)

cat > ssh_config << EOF
UserKnownHostsFile /dev/null
StrictHostKeyChecking no
User root
ConnectTimeout 10

Host host
  Hostname ${h}
EOF

ssh="ssh -F ssh_config"
scp="scp -F ssh_config"

$ssh host yum -y install libvirt libvirt-devel qemu-kvm virt-install libguestfs-tools bind-utils
$ssh host service libvirtd start

if [ -e ${os}.img ]; then
  scp -F ssh_config ${os}.img host:/var/lib/libvirt/
else
  $ssh host yum -y install libguestfs-tools
  $ssh host virt-builder ${osname}-${osver} \
    --hostname foreman-${os}.example.com \
    --format qcow2 -o /var/lib/libvirt/${os}.img ${args}
  scp -F ssh_config host:/var/lib/libvirt/${os}.img ./
fi

$ssh host virt-install --import \
  --name ${os} --ram 4096 --disk path=:/var/lib/libvirt/${os}.img,format=qcow2 \
  --os-variant ${osvariant} --noautoconsole

# Wait for IP to be allocated in dnsmasq
i=600
while [ $i -gt 0 ]; do
  ip=$($ssh host dig +short foreman-${os} @192.168.122.1)
  [ -n "$ip" ] && break
  sleep 10
  i=$(($i - 10))
done

if [ -z "$ip" ]; then
  echo "No IP found for foreman-${os}"
  exit 1
fi

cat >> ssh_config << EOF
Host ${os}
  Hostname ${ip}
EOF

# Wait for IP to respond normally
i=600
while [ $i -gt 0 ]; do
  if $ssh $os true; then
    echo "SSH is responding on foreman-$os"
    exit 0
  fi
  sleep 10
  i=$(($i - 10))
done

echo "Server did not respond in time."
exit 1
