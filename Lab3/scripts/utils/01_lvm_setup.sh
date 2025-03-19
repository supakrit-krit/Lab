#!/bin/bash
echo "Create LVM"
mkdir -p /share/home
mkdir -p /share/projects
chmod 770 /share/home
chmod 755 /share/projects
pvcreate /dev/nvme0n2
vgcreate vg_home /dev/nvme0n2
lvcreate -L 5G -T vg_share/thinpool
lvcreate -V 10G -T vg_share/thinpool -n home
lvcreate -V 10G -T vg_share/thinpool -n project
mkfs.xfs /dev/vg_share/home
mkfs.xfs /dev/vg_share/project
echo "/dev/vg_share/home /share/home xfs defaults 0 0" >> /etc/fstab
echo "/dev/vg_share/home /share/project xfs defaults 0 0" >> /etc/fstab