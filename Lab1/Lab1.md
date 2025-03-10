Lab1: NFS, FreeIPA
=========

>Username: krit
>Password: lab1password

>Resources:
>1. VMware Fusion (Professional Version 13.6.3)
>2. [Rocky Linux 9 (2 VMS: Node1, Node2)](https://rockylinux.org/download)

NFS
------

#### Node1 (192.168.30.139): NFS Server

``` sh
dnf install -y nfs-utils
mkdir /mnt/nfs_share
chmod 777 /mnt/nfs_share/
echo "/mnt/nfs_share 192.168.30.0/24(rw,sync,no_subtree_check)" > /etc/exports
firewall-cmd --add-service=nfs --permanent
firewall-cmd --reload
exportfs -arv
``` 

#### Node2 (192.168.30.140): NFS Client

``` sh
dnf install -y nfs-utils
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

> **Tips:** 
comment out if not use

NFS with autofs:
------

#### Node1 (192.168.30.139)

``` sh
dnf install -y autofs
systemctl enable --now autofs
``` 

#### Node2 (192.168.30.140) 

``` sh
dnf install autofs -y
systemctl enable --now autofs
echo "/mnt /etc/auto.nfs --timeout=300" >> auto.master
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

#### Problem
- Users on the client machine are inheriting UID-based permissions from the server.
    1. [map user from client to server user at /etc/exports](https://www.opswat.com/docs/mdss/knowledge-base/what-is-user-squashing-for-network-file-system-nfs)
    >``` bash
    >echo "/mnt/nfs_share 192.168.30.0/24(rw,sync,no_subtree_check,anonuid=1000,anongid=1000)" > /etc/exports
    >exportfs -arv
    >```

    2. using FreeIPA

FreeIPA
------

#### Node3 (192.168.30.141): IPA Server

``` bash
# The hostname must be fully-qualified (server.ipa.test)
hostnamectl set-hostname node3.ipa.test
# The ports that IPA uses will need to be opened so remote clients or additional IPA masters will be able to connect.
firewall-cmd --permanent --add-port={80/tcp,443/tcp,389/tcp,636/tcp,88/tcp,464/tcp,53/tcp,88/udp,464/udp,53/udp,123/udp}
firewall-cmd --reload
# Install FreeIPA server. From a root terminal, run:
dnf install -y freeipa-server freeipa-server-dns
reboot
# Run FreeIPA server
ipa-server-install \
  --realm=IPA.TEST \
  --domain=ipa.test \
  --hostname=node3.ipa.test \
  --setup-dns \
  --auto-forwarders \
  --mkhomedir \
  -p 'lab1password' \
  -a 'lab1password' -U
# To authenticate as the admin, just run:
kinit admin
```

> **Note:** 
>- Do not use an existing domain or hostname unless you own the domain. It’s a common mistake to use example.com. We recommend to use a reserved top level domain from RFC2606 for private test installations, e.g. ipa.test.
>- freeIPA requires an absolute minimum of 1.2GB to install with a CA. 2GB is recommended for a demo/test system.

#### Node2 (192.168.30.140): IPA Client

``` bash
echo "192.168.30.141 node3.ipa.test node3" >> /etc/hosts
ping node3.ipa.test
```

``` bash
hostnamectl set-hostname node2.ipa.test
dnf install -y ipa-client
firewall-cmd --permanent --add-service=freeipa-ldap
firewall-cmd --permanent --add-service=freeipa-ldaps
firewall-cmd --reload
reboot
ipa-client-install \
  --hostname=node2.ipa.test \
  --mkhomedir \
  --server=node3.ipa.test \
  --domain=ipa.test \
  --realm=IPA.TEST \
  --principal=admin \
  --password=lab1password \
  --enable-dns-updates -U
kinit admin
```

#### IPA commands

``` bash
ipa-server-install --uninstall
ipa user-add newuser --first="New" --last="User" --password
ipa user-find newuser
```

Disscussion
=====

### Q: Should the FreeIPA Server Be Separate from the NFS Server?

| **Criteria**           | **Same Server (Combined FreeIPA & NFS)** | **Separate Servers (FreeIPA & NFS Split)** |
|------------------------|--------------------------------|--------------------------------|
| **Security**          | ❌ Higher risk if compromised | ✅ Stronger isolation & security |
| **Performance**       | ❌ Can slow down under heavy load | ✅ Better resource distribution |
| **Scalability**       | ❌ Harder to expand | ✅ Can scale NFS and FreeIPA separately |
| **Setup Complexity**  | ✅ Easier, fewer machines to configure | ❌ Requires more initial setup |
| **Maintenance**       | ❌ Updating/restarting affects both services | ✅ Independent management & troubleshooting |
| **Hardware/VM Usage** | ✅ Saves resources (1 machine instead of 2) | ❌ Requires more resources |
| **Best For**          | ✔ Small setups, testing environments | ✔ Production, enterprise, high-security needs |


>Reference: 
>1.	https://www.freeipa.org/page/Quick_Start_Guide
>2. https://www.linode.com/docs/guides/freeipa-for-identity-management/
