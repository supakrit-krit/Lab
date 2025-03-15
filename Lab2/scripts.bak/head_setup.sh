#!/bin/bash

# Disable SELinux
echo "Disabling SELinux..."
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

echo "Installing necessary packages..."
dnf install -y epel-release screen

echo "Creating shared directories..."
mkdir -p /share/projects
chmod 755 /share/projects

# Create LVM with NVMe thin disk 100G
echo "Setting up LVM on NVMe disk..."
pvcreate /dev/nvme0n2
vgcreate vg_home /dev/nvme0n2
lvcreate -L 100G -T vg_home/thinpool
lvcreate -V 100G -T vg_home/thinpool -n lv_home
mkfs.xfs /dev/vg_home/lv_home
mkdir -p /share/home
mount /dev/vg_home/lv_home /share/home
echo "/dev/vg_home/lv_home /share/home xfs defaults 0 0" >> /etc/fstab

echo "Configuring network interfaces..."
# Set up public and private networks (adjust interfaces accordingly)
nmcli con add type ethernet ifname eth0 con-name public ipv4.method manual ipv4.addresses "192.168.1.100/24"
nmcli con add type ethernet ifname eth1 con-name private ipv4.method manual ipv4.addresses "10.10.10.1/24"
nmcli con up public
nmcli con up private

echo "Setting hostname..."
hostnamectl set-hostname head.ipa.test
systemctl restart systemd-hostnamed

read -p "Compute node IP: " COM_IP
echo "Adding compute node to /etc/hosts..."
echo "${COM_IP} com1.ipa.test com1" >> /etc/hosts

echo "Installing NFS utilities..."
dnf install -y nfs-utils

echo "Configuring NFS exports..."
echo "/share/home 10.10.10.0/24(rw,sync,no_root_squash)" >> /etc/exports
echo "/share/projects 10.10.10.0/24(rw,sync,no_root_squash)" >> /etc/exports

echo "Setting up firewall rules for NFS..."
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload
firewall-cmd --reload

echo "Starting RPC and exporting NFS shares..."
exportfs -arv

echo "Installing FreeIPA Server..."
dnf install -y freeipa-server freeipa-server-dns

echo "Configuring firewall for FreeIPA..."
firewall-cmd --permanent --add-port={80/tcp,443/tcp,389/tcp,636/tcp,88/tcp,464/tcp,53/tcp,88/udp,464/udp,53/udp,123/udp}
firewall-cmd --reload

echo "Ensuring home directories are created with correct permissions..."
sed -i '/^session.*revoke/i session    required                                     pam_mkhomedir.so skel=/etc/skel/ umask=0077' /etc/pam.d/password-auth
sed -i '/^session.*revoke/i session    required                                     pam_mkhomedir.so skel=/etc/skel/ umask=0077' /etc/pam.d/system-auth

echo "Installing and configuring IPA Server..."
ipa-server-install \
  --realm=IPA.TEST \
  --domain=ipa.test \
  --hostname=head.ipa.test \
  --setup-dns \
  --auto-forwarders \
  --mkhomedir \
  -p 'lab2password' \
  -a 'lab2password' -U

kinit admin

echo "Installing Grafana and Prometheus..."
dnf install -y grafana prometheus
systemctl enable --now grafana-server
systemctl enable --now prometheus

echo "Head node setup complete. A system reboot is recommended."