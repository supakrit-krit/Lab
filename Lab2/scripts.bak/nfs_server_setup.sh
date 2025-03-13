#!/bin/bash

# Define variables
NFS_SHARE="/share/project"
NFS_HOME="/share/home"
EXPORTS_FILE="/etc/exports"

echo "📌 Step 1: Installing necessary packages..."
dnf install -y nfs-utils

echo "📌 Step 2: Creating and setting up the NFS shared directory..."
mkdir -p $NFS_SHARE
mkdir -p $NFS_HOME
chmod 770 /share
chmod 755 $NFS_SHARE
chmod 770 $NFS_HOME

echo "📌 Step 3: Detecting Network Subnet..."
# Get the default network interface
NET_INTERFACE=$(ip route | grep default | awk '{print $5}')

# Get the subnet and netmask dynamically
SUBNET_INFO=$(ip -o -f inet addr show $NET_INTERFACE | awk '{print $4}')

echo "🔍 Detected Subnet: $SUBNET_INFO"

echo "📌 Step 4: Configuring NFS exports..."
# Backup existing exports file
cp $EXPORTS_FILE ${EXPORTS_FILE}.bak

# Add NFS share rule (if not already present)
if ! grep -q "$NFS_SHARE" $EXPORTS_FILE; then
    echo "$NFS_HOME $SUBNET_INFO(rw,sync,no_subtree_check,no_root_squash)" >> $EXPORTS_FILE
    echo "$NFS_SHARE $SUBNET_INFO(rw,sync,no_subtree_check,no_root_squash)" >> $EXPORTS_FILE
fi

echo "📌 Step 5: Configuring firewall rules..."
firewall-cmd --permanent --add-service={freeipa-ldap,freeipa-ldaps,http,https,ntp,kpasswd,dns}
firewall-cmd --reload

echo "📌 Step 6: Restarting NFS services..."
systemctl enable --now nfs-server
exportfs -arv

echo "✅ NFS Server Setup Complete! Clients can now mount: $NFS_SHARE and $NFS_HOME"
