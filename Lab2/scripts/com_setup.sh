#!/bin/bash

# Disable SELinux
echo "Disabling SELinux..."
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

echo "Creating shared directories..."
mkdir -p /share/projects
chmod 755 /share/projects

DOMAIN="ipa.test"
REALM="IPA.TEST"

read -p "Compute node name: " COM_NAME
echo "Setting hostname..."
hostnamectl set-hostname ${COM_NAME}.${DOMAIN}
systemctl restart systemd-hostnamed

read -p "Compute node IP: " COM_IP
ip -br a
read -p "Head node IP: " HEAD_IP
echo "Adding compute node to /etc/hosts..."
echo "${HEAD_IP} head.ipa.test head" >> /etc/hosts
echo "${COM_IP} ${COM_NAME}.ipa.test ${COM_NAME}" >> /etc/hosts

dnf install -y nfs-utils

mkdir -p /share/home
chmod 770 /share
chmod 770 /share/home

echo "${HEAD_IP}:/share/home /share/home nfs defaults 0 0" >> /etc/fstab
echo "${HEAD_IP}:/share/projects /share/projects nfs defaults 0 0" >> /etc/fstab
firewall-cmd --add-service=nfs --permanent
firewall-cmd --reload
mount -av

echo "Installing FreeIPA Server..."

# Variables
IPA_SERVER="head.${DOMAIN}"
HOSTNAME="${COM_NAME}.${DOMAIN}"

dnf install -y freeipa-client

# Configure the firewall
echo "Configuring the firewall..."
firewall-cmd --permanent --add-service=freeipa-ldap
firewall-cmd --permanent --add-service=freeipa-ldaps
firewall-cmd --add-service=dns --permanent

sudo firewall-cmd --permanent --add-service={http,https,ldap,ldaps,kerberos,kpasswd,ntp}
firewall-cmd --permanent --add-port={80/tcp,443/tcp,389/tcp,636/tcp,88/tcp,464/tcp,53/tcp,88/udp,464/udp,53/udp,123/udp}
firewall-cmd --reload

# ## Run the FreeIPA client installation
ipa-client-install \
  --hostname=com2.ipa.test \
  --mkhomedir \
  --server=head.ipa.test \
  --domain=ipa.test \
  --realm=IPA.TEST \
  --principal=admin \
  --password=lab2password \
  --enable-dns-updates -U
echo "Running ipa-client-install..."
ipa-client-install \
  --hostname=${HOSTNAME} \
  --mkhomedir \
  --server=${IPA_SERVER} \
  --domain=${DOMAIN} \
  --realm=${REALM} \
  --principal=admin \
  --password=lab2password \
  --enable-dns-updates -U