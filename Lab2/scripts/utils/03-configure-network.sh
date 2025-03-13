#!/bin/bash

echo "Configuring network interfaces..."
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.1.1
NETMASK=255.255.255.0
EOF

nmcli con reload
systemctl restart NetworkManager
echo "Network configuration complete."
