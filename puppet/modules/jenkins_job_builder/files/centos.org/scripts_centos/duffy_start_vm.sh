#!/bin/bash -e

RSYNC_PASSWORD=$(cut -d- -f1-2 ~/duffy.key)
set -x

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
  args="--firstboot-command \"dpkg-reconfigure openssh-server\""
elif [ ${os} = trusty ]; then
  osname=ubuntu
  osver=14.04
  osvariant=${osname}13.04
  args="--firstboot-command \"dpkg-reconfigure openssh-server\""
elif [ ${os} = wheezy ]; then
  osname=debian
  osver=7
  args="--firstboot-command \"dpkg-reconfigure openssh-server\""
  osvariant=${osname}${osver}
elif [ ${os} = jessie ]; then
  osname=debian
  osver=8
  osvariant=${osname}7
  args="--firstboot-command \"dpkg-reconfigure openssh-server\""
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

$ssh host yum -y install libvirt libvirt-devel qemu-kvm virt-install bind-utils libguestfs-tools rsync
$ssh host service libvirtd start

# Keep virt-builder cache on artifacts server for speed
$ssh host mkdir .cache
# stdin for security
$ssh host <<EOF
RSYNC_PASSWORD=$RSYNC_PASSWORD rsync -av foreman@artifacts.ci.centos.org::foreman/virt-builder-cache/ /root/.cache/virt-builder/
EOF

$ssh host virt-builder ${osname}-${osver} \
  --hostname foreman-${os}.example.com \
  --format qcow2 -o /var/lib/libvirt/images/${os}.img ${args} \
  --mkdir /root/.ssh --run-command "'chmod 0700 /root/.ssh'" \
  --upload /root/.ssh/authorized_keys:/root/.ssh/authorized_keys

# Sync cache back
$ssh host <<EOF
RSYNC_PASSWORD=$RSYNC_PASSWORD rsync -av /root/.cache/virt-builder/ foreman@artifacts.ci.centos.org::foreman/virt-builder-cache/
EOF

$ssh host virt-install --import \
  --name ${os} --ram 4096 --disk path=/var/lib/libvirt/images/${os}.img,format=qcow2 \
  --os-variant ${osvariant} --noautoconsole

# Wait for IP to be allocated in dnsmasq
i=600
while [ $i -gt 0 ]; do
  ip=$($ssh host dig +short foreman-${os} @192.168.122.1 | head -n 1)
  # Recursive resolvers are returning IPs on NXDOMAIN, so check subnet's correct too
  [ -n "$ip" ] && [[ "$ip" =~ ^192\.168\.122 ]] && break
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
  ProxyCommand ssh -F ssh_config host -W %h:%p 2>/dev/null
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
