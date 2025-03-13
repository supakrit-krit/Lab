#!/bin/bash

read -p "Server IP: " NFS_SERVER

# Define variables
NFS_SHARE="/share/project"
NFS_HOME="/share/home"
MOUNT_POINT="/share/project"
MOUNT_HOME="/share/home"

echo "📌 Step 1: Installing necessary packages..."
dnf install -y nfs-utils

echo "📌 Step 2: Creating mount directory..."
mkdir -p $MOUNT_POINT
mkdir -p $MOUNT_HOME
chmod 755 $MOUNT_POINT
chmod 770 $MOUNT_HOME

echo "📌 Step 3: Configuring firewall rules..."
firewall-cmd --permanent --add-service={freeipa-ldap,freeipa-ldaps,http,https,ntp,kpasswd,dns}
firewall-cmd --reload

echo "📌 Step 4: Configuring fstab..."
echo "${NFS_SERVER}:${NFS_SHARE} ${MOUNT_POINT} nfs defaults 0 0" >> /etc/fstab
echo "${NFS_SERVER}:${NFS_HOME} ${MOUNT_HOME} nfs defaults 0 0" >> /etc/fstab
mount -av

echo "✅ Setup Complete! You can access the mount at: /mnt/nfs_client"
