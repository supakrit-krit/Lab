#!/bin/bash

read -p "Node name: " NODE

# Variables
DOMAIN="ipa.test"
REALM="IPA.TEST"
IPA_SERVER="node3.${DOMAIN}"
HOSTNAME="${NODE}.${DOMAIN}"

echo "Node name: $NODE"
echo "Hostname: $HOSTNAME"
echo "IPA Server: $IPA_SERVER"

# Set the hostname
echo "Setting hostname to ${HOSTNAME}..."
hostnamectl set-hostname ${HOSTNAME}

# Update the system
echo "Updating system packages..."
dnf update -y

# Install FreeIPA client packages
echo "Installing FreeIPA client packages..."
dnf install -y freeipa-client

# Configure the firewall
echo "Configuring the firewall..."
firewall-cmd --permanent --add-service=freeipa-ldap
firewall-cmd --permanent --add-service=freeipa-ldaps
firewall-cmd --add-service=dns --permanent
firewall-cmd --reload

# Run the FreeIPA client installation
echo "Running ipa-client-install..."
ipa-client-install \
  --hostname=${HOSTNAME} \
  --mkhomedir \
  --server=node3.ipa.test \
  --domain=${DOMAIN} \
  --realm=${REALM} \
  --principal=admin \
  --password=lab1password \
  --enable-dns-updates -U

# To authenticate as the admin, just run:
echo "FreeIPA Client setup is complete!"

kinit admin