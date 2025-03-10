#!/bin/bash

# Define variables
NFS_SHARE="/mnt/nfs_share"
EXPORTS_FILE="/etc/exports"

echo "📌 Step 1: Installing necessary packages..."
dnf install -y nfs-utils autofs

echo "📌 Step 2: Creating and setting up the NFS shared directory..."
mkdir -p $NFS_SHARE
chmod 777 $NFS_SHARE

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
    echo "$NFS_SHARE $SUBNET_INFO(rw,sync,no_subtree_check)" >> $EXPORTS_FILE
fi

echo "📌 Step 5: Configuring firewall rules..."
firewall-cmd --add-service=nfs --permanent
firewall-cmd --reload

echo "📌 Step 6: Restarting NFS services..."
systemctl enable --now nfs-server
exportfs -arv

echo "✅ NFS Server Setup Complete! Clients can now mount: $NFS_SHARE"
