#!/bin/bash

echo "Installing NFS server..."
dnf install -y nfs-utils

mkdir -p /share/home /share/project
chmod 770 /share/home
chmod 755 /share/project
chown nobody:nobody /share/home /share/project

cat <<EOF >> /etc/exports
/share/home    *(rw,sync,no_root_squash)
/share/project *(rw,sync,no_root_squash)
EOF

exportfs -av
systemctl enable --now nfs-server
echo "NFS server installation complete."
