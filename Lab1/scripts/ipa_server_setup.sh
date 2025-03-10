#!/bin/bash

read -p "Node name: " NODE

# Variables
DOMAIN="ipa.test"
REALM="IPA.TEST"
HOSTNAME="${NODE}.${DOMAIN}"

# Set the hostname
echo "Setting hostname to ${HOSTNAME}..."
hostnamectl set-hostname ${HOSTNAME}

# Update the system
echo "Updating system packages..."
dnf update -y

# Install FreeIPA server packages
echo "Installing FreeIPA server packages..."
dnf install -y freeipa-server freeipa-server-dns

# Configure the firewall
echo "Configuring the firewall..."
firewall-cmd --permanent --add-service={freeipa-ldap,freeipa-ldaps,http,https,ntp,kpasswd,dns}
firewall-cmd --reload

# Run the FreeIPA server installation
echo "Running ipa-server-install..."
ipa-server-install \
  --realm=${REALM} \
  --domain=${DOMAIN} \
  --hostname=${HOSTNAME} \
  --setup-dns \
  --auto-forwarders \
  --mkhomedir \
  -p 'lab1password' \
  -a 'lab1password' -U

# To authenticate as the admin, just run:
echo "FreeIPA Server setup is complete!"

kinit admin