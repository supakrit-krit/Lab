#!/bin/bash

# Define variables
NFS_SERVER="192.168.30.139"
NFS_SHARE="/mnt/nfs_share"
MOUNT_POINT="/mnt/nfs_client"
AUTOFS_MASTER="/etc/auto.master"
AUTOFS_NFS="/etc/auto.nfs"

echo "📌 Step 1: Installing necessary packages..."
dnf install -y nfs-utils autofs

echo "📌 Step 2: Creating mount directory..."
mkdir -p $MOUNT_POINT
chmod 777 $MOUNT_POINT

echo "📌 Step 3: Configuring autofs..."

# Backup existing auto.master
cp $AUTOFS_MASTER ${AUTOFS_MASTER}.bak

# Ensure /mnt is registered in auto.master
if ! grep -q "^/mnt" $AUTOFS_MASTER; then
    echo "/mnt /etc/auto.nfs --timeout=300" >> $AUTOFS_MASTER
fi

# Create auto.nfs for NFS mount
echo "nfs_client -fstype=nfs,rw $NFS_SERVER:$NFS_SHARE" > $AUTOFS_NFS

echo "📌 Step 4: Restarting autofs service..."
systemctl restart autofs
systemctl enable autofs

echo "✅ Setup Complete! You can access the mount at: /mnt/nfs_client"
