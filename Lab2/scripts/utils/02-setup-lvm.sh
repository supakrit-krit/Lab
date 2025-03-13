#!/bin/bash

# Prompt for Disk
read -p "Enter the disk for LVM (e.g., /dev/sdX): " DISK
if [ ! -b "$DISK" ]; then
    echo "Invalid disk: $DISK does not exist. Exiting."
    exit 1
fi

VG_NAME="vg_share"
LV_NAME="lv_home"

echo "Configuring LVM on $DISK..."
pvcreate $DISK
vgcreate $VG_NAME $DISK
lvcreate -L 100G -T $VG_NAME/thinpool
lvcreate -V 100G -T $VG_NAME/thinpool -n $LV_NAME
mkfs.xfs /dev/$VG_NAME/$LV_NAME

mkdir -p /share/home
mount /dev/$VG_NAME/$LV_NAME /share/home
echo "/dev/$VG_NAME/$LV_NAME /share/home xfs defaults 0 0" >> /etc/fstab
echo "LVM setup complete."
