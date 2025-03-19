#!/bin/bash

# Disable SELinux
echo "Disabling SELinux..."
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

###### create LVM ######
echo "Create LVM"
mkdir -p /share/home
mkdir -p /share/projects
chmod 770 /share/home
chmod 755 /share/projects
pvcreate /dev/nvme0n2
vgcreate vg_share /dev/nvme0n2
lvcreate -L 5G -T vg_share/thinpool
lvcreate -V 10G -T vg_share/thinpool -n home
lvcreate -V 10G -T vg_share/thinpool -n project
mkfs.xfs /dev/vg_share/home
mkfs.xfs /dev/vg_share/project
echo "/dev/mapper/vg_share-home /share/home xfs defaults,usrquota,grpquota 0 0" >> /etc/fstab
echo "/dev/mapper/vg_share-project /share/projects xfs defaults,usrquota,grpquota 0 0" >> /etc/fstab
# echo "/dev/vg_share/home /share/home xfs defaults 0 0" >> /etc/fstab
# echo "/dev/vg_share/home /share/project xfs defaults 0 0" >> /etc/fstab
########################

###### Hostname ######
echo "Setting hostname..."
hostnamectl set-hostname head.ipa.test
read -p "Compute node name: " COM_NAME
read -p "Compute node IP: " COM_IP
ip -br a
read -p "Head node IP: " HEAD_IP
echo "Adding compute node to /etc/hosts..."
echo "${HEAD_IP} head.ipa.test head" >> /etc/hosts
echo "${COM_IP} ${COM_NAME}.ipa.test ${COM_NAME}" >> /etc/hosts
echo "Reboot to update hostname"
reboot
#################

###### NFS ######
echo "Installing NFS utilities..."
dnf install -y nfs-utils
echo "Configuring NFS exports..."
echo "/share/home 10.10.10.0/24(rw,sync,no_root_squash)" >> /etc/exports
echo "/share/projects 10.10.10.0/24(rw,sync,no_root_squash)" >> /etc/exports
echo "Setting up firewall rules for NFS..."
firewall-cmd --permanent --add-service=nfs
firewall-cmd --reload
echo "Starting RPC and exporting NFS shares..."
exportfs -arv
systemctl enable --now nfs-server
#################

####### FreeIPA ######
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
  --no-forwarders \
  --mkhomedir \
  -p 'lab3password' \
  -a 'lab3password' -U

systemctl enable --now krb5kdc
kinit admin
# passwordless require init login and check krb5kdc ticket 
ipa user-show ipa1
systemctl stop sssd ; rm -rf /var/lib/sss/db/* ; systemctl restart sssd
##############

###### Quota ######
xfs_quota -x -c "report -h" /share/home
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa1" /share/home
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa2" /share/home
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa3" /share/home
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa4" /share/home
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa5" /share/home
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa6" /share/home
xfs_quota -x -c "report -h" /share/projects
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa1" /share/projects
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa2" /share/projects
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa3" /share/projects
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa4" /share/projects
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa5" /share/projects
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa6" /share/projects
# new user default
xfs_quota -x -c "limit -d bsoft=15m bhard=20m" /share/home
xfs_quota -x -c "limit -d bsoft=15m bhard=20m" /share/projects
# for group quota
# xfs_quota -x -c 'enable -g' /data
xfs_quota -x -c "limit -g bsoft=15m bhard=20m team1" /share/projects
xfs_quota -x -c "limit -g bsoft=15m bhard=20m team2" /share/projects
xfs_quota -x -c "report -g" /share/projects
# if set timer
# xfs_quota -x -c "timer -g btime=7d" /data
# # check folder size
# du -sh  ../ipa1
# # if=data-source
# dd if=/dev/zero of=testfile bs=1M count=10
# # Allocates 10MB of disk space without writing zeroes.
# fallocate -l 10M testfile
##################

###### ACL #######
mkdir -p /share/projects/{.backup,00_guest,01_quickShare,02_lecture,03_team1,04_team2,99_Archived}
mkdir -p /share/projects/.backup/{2503_projectName1,2503_projectName2}
mkdir -p /share/projects/01_quickShare/{2503_projectName1,2503_projectName2}
mkdir -p /share/projects/02_lecture
mkdir -p /share/projects/03_team1/{2503_projectName1,2503_projectName2,9999_Archived}
mkdir -p /share/projects/04_team2/{2503_projectName1,2503_projectName2,9999_Archived}
# Allow team1 full access to 03_team1
setfacl -m g:team1:rwx /share/projects/03_team1
setfacl -R -m g:team1:rwx /share/projects/03_team1/*
# Allow team2 full access to 04_team2
setfacl -m g:team2:rwx /share/projects/04_team2
setfacl -m d:g:team1:rwx /share/projects/03_team1
setfacl -R -m g:team2:rwx /share/projects/04_team2/*
# Allow backup team full access to .backup
setfacl -m g:ipa-sudo:rwx /share/projects/.backup
setfacl -R -m g:ipa-sudo:rwx /share/projects/.backup/*
# Allow lecture team access to 02_lecture
setfacl -m g:lecturer:rx /share/projects/02_lecture
setfacl -R -m g:lecturer:rx /share/projects/02_lecture/*
# Allow everyone read/write access to 01_quickShare
setfacl -m o:rwx /share/projects/01_quickShare
setfacl -R -m o:rwx /share/projects/01_quickShare/*
chown -R lecturer:lecturer 02_lecture
setfacl -R -m g:lecturer:rwx 02_lecture
setfacl -R -m d:g:lecturer:rwx 02_lecture
mkdir -p 02_lecture/01_introduction 02_lecture/02_basic 02_lecture/03_intermediate 02_lecture/04_advance 02_lecture/05_expert
# Step 2: Create chapter files
echo "intro chap1" > 02_lecture/01_introduction/01_chapter
echo "intro chap2" > 02_lecture/01_introduction/02_chapter
echo "basic chap1" > 02_lecture/02_basic/01_chapter
echo "basic chap2" > 02_lecture/02_basic/02_chapter
echo "inter chap1" > 02_lecture/03_intermediate/01_chapter
echo "inter chap2" > 02_lecture/03_intermediate/02_chapter
echo "advance chap1" > 02_lecture/04_advance/01_chapter
echo "advance chap2" > 02_lecture/04_advance/02_chapter
echo "expert chap1" > 02_lecture/05_expert/01_chapter
echo "expert chap2" > 02_lecture/05_expert/02_chapter

setfacl -m g:learner:r-x 02_lecture
setfacl -m d:g:learner:--- 02_lecture
# learn_starter
setfacl -m g:learn_starter:r-x 02_lecture/01_introduction
setfacl -m g:learn_starter:r-x 02_lecture/02_basic
# --
setfacl -m g:learn_starter:0 02_lecture/03_intermediate
setfacl -m g:learn_starter:0 02_lecture/04_advance
setfacl -m g:learn_starter:0 02_lecture/05_expert
# learn_intermediate
setfacl -m g:learn_intermediate:r-x 02_lecture/01_introduction
setfacl -m g:learn_intermediate:r-x 02_lecture/02_basic
setfacl -m g:learn_intermediate:r-x 02_lecture/03_intermediate
setfacl -m g:learn_intermediate:r-x 02_lecture/04_advance
# --
setfacl -m g:learn_intermediate:0 02_lecture/05_expert
# instructor
setfacl -m g:learn_expert:r-x 02_lecture/01_introduction
setfacl -m g:learn_expert:r-x 02_lecture/02_basic
setfacl -m g:learn_expert:r-x 02_lecture/03_intermediate
setfacl -m g:learn_expert:r-x 02_lecture/04_advance
setfacl -m g:learn_expert:r-x 02_lecture/05_expert
##################

##### Grafana ######
echo "Installing Grafana and Prometheus..."
dnf install -y grafana prometheus
systemctl enable --now grafana-server
systemctl enable --now prometheus

echo "Head node setup complete. A system reboot is recommended."