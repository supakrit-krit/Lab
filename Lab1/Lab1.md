Lab1: NFS, FreeIPA
=========

>Username: krit
>Password: lab1password

>Resources:
>1. VMware Fusion (Professional Version 13.6.3)
>2. Rocky Linux 9: https://rockylinux.org/download (2 VMS: Node1, Node2)

NFS
------

#### Node1 (192.168.30.139)

``` sh
dnf install nfs-utils -y
mkdir /mnt/nfs_share
chmod 777 /mnt/nfs_share/
echo “/mnt/nfs_share 192.168.30.0/24(rw,sync,no_subtree_check)” > /etc/exports
firewall-cmd --add-service=nfs --permanent
firewall-cmd --reload
exportfs -arv
``` 

#### Node2 (192.168.30.140) 

``` sh
dnf install nfs-utils -y
mkdir /mnt/nfs_client
chmod 777 /mnt/nfs_client/
sudo mount -t nfs 192.168.30.139:/mnt/nfs_share /mnt/nfs_client
```

#### Problem
- After rebooting, the partition is unmounted.
    1. Using fstab
    2. Using autofs

fstab
------

#### Node2 (192.168.30.140): 

``` sh
echo "192.168.30.139:/mnt/nfs_share /mnt/nfs_client nfs defaults 0 0" >> /etc/fstab
mount -av
```

NFS with autofs:
------

#### Node1 (192.168.30.139)

``` sh
dnf install autofs -y
echo "/mnt/nfs_share 192.168.30.0/24(rw,sync,no_subtree_check)"
``` 

#### Node2 (192.168.30.140) 

``` sh
dnf install autofs -y
vi /etc/auto.master
echo "nfs_client -fstype=nfs,rw 192.168.30.139:/mnt/nfs_share" > /etc/auto.nfs
systemctl restart autofs
```

``` /etc/auto.master
#
# Sample auto.master file
# This is an automounter map and it has the following format
# key [ -mount-options-separated-by-comma ] location
# For details of the format look at autofs(5).
#
/misc  /etc/auto.misc
/net -hosts
/mnt /etc/auto.nfs --timeout=300
#
#Include /etc/auto.master.d/*.autofs
#
#+dir:/etc/auto.master.d
#
# Include central master map if it can be found using
# nsswitch sources.
#
# Note that if there are entries for /net or /misc (as
# above) in the included master map any keys that are the
# same will not be seen as the first read key seen takes
# precedence.
#
+auto.master
```

sudo nano /etc/fstab


>Reference: 
>1.	https://bluexp.netapp.com/blog/azure-anf-blg-linux-nfs-server-how-to-set-up-server-and-client
>2.	https://www.opswat.com/docs/mdss/knowledge-base/what-is-user-squashing-for-network-file-system-nfs

FreeIPA:

