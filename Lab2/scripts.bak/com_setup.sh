dnf install -y nfs-utils
mkdir -p /share/home
mkdir -p /share/projects
chmod 770 /share
chmod 770 /share/home
chmod 770 /share/projects
echo "10.10.10.128:/share/home /share/home nfs defaults 0 0" >> /etc/fstab
echo "10.10.10.128:/share/projects /share/projects nfs defaults 0 0" >> /etc/fstab
firewall-cmd --add-service=nfs --permanent
firewall-cmd --reload
mount -av