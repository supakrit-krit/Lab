Lab2.1: HPC Fix
=========

Requirements
------

Fix

- ssh passwordless: public key authen
- sudoer on freeIPA
- nfs quota
- nfs access control list
    - projects structure
- Grafana, Prometheus, node-exporter

Head Node (192.168.30.142): head:lab2password
    - Having FreeIPA, NFS Server

- Q: Logival volumn and Virtual volumn [reference](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html/logical_volume_manager_administration/thinly_provisioned_volume_creation#thinly_provisioned_volume_creation)

Note that in this case you are specifying virtual size, and that you are specifying a virtual size for the volume that is greater than the pool that contains it.

You can extend the size of a thin volume with the lvextend command. You cannot, however, reduce the size of a thin pool.

``` 
# lvcreate -L 100M -T vg001/mythinpool
  Rounding up size to full physical extent 4.00 MiB
  Logical volume "mythinpool" created
# lvs
  LV            VG     Attr     LSize   Pool Origin Data%  Move Log Copy% Convert
  my mythinpool vg001  twi-a-tz 100.00m               0.00
# lvcreate -V1G -T vg001/mythinpool -n thinvolume
  Logical volume "thinvolume" created
# lvs
  LV          VG       Attr     LSize   Pool       Origin Data%  Move Log Copy%  Convert
  mythinpool  vg001    twi-a-tz 100.00m                     0.00                        
  thinvolume  vg001    Vwi-a-tz   1.00g mythinpool          0.00
```

``` bash
# deactivate
lvchange -an vg_share/home
lvremove vg_share/home
# create thinpool(1G)
lvcreate -L 1G -T vg_share/home
# create thinvolumn(10G) inside thinpool(1G)
lvcreate -V 10G -T vg_share/home -n home
mkfs.xfs /dev/vg_share/home
mount /dev/vg_share/lv_home /share/home
lvextend -l +100%FREE /dev/vg_share/home
lvextend -L +1G /dev/vg_share/home
```

``` bash
tar -czvf /bak/home.tar.gz /share/home
tar -xvzf /bak/home.tar.gz -C /
```

SSH passwordless: public key authen [tutorial](https://www.informaticar.net/password-less-authetication-on-centos-red-hat/)
------

At M213

``` bash
ssh-keygen -t rsa
chmod 600 ~/.ssh/m213
chmod 600 ~/.ssh/m213.pub
# (base) kitt@M213 .ssh % ls -al | grep m213   
# -rw-------   1 kitt  staff   2602 Mar 17 14:03 m213
# -rw-------   1 kitt  staff    569 Mar 17 14:03 m213.pub
# copy src des
scp m213.pub ipa1@head:.ssh/authorized_keys
# OR on FreeIPA UI add m213.pub to ssh pub field
# ssh -i <private-key> <user>@<host> after store .pub at head
ssh -i m213 ipa3@head
```

At head

``` bash
# nano /etc/krb5.conf
# [libdefaults]
#     ticket_lifetime = 24h
#     renew_lifetime = 7d
#     forwardable = true
#     default_realm = IPA.TEST
systemctl restart krb5kdc
# To check the ticket lifetime and renewal settings for a specific user:
ipa user-show <username>
ipa user-mod <username> --krbmaxticketlife=24h --krbmaxrenewableage=7d
# at M213 -> store m213.pub to head (.ssh/authorized_keys)
vi /etc/ssh/sshd_config
## PubkeyAuthentication yes
## AuthorizedKeysFile .ssh/authorized_keys
# copy of m213.pub
# check file name
## mv m213.pub authorized_keys
# check permission 
## chmod 600 ~/.ssh/authorized_keys
## FreeIPA
# ssh-keygen -t rsa
# store pub at IPA UI
ssh com1
```

sudoer on freeIPA (tutorial)[https://freeipa.readthedocs.io/en/latest/workshop/8-sudorule.html]
-----


NFS quota [tutorial](https://reintech.io/blog/setting-up-disk-quotas-rocky-linux-9)
------

At head fs: xfs

``` bash
# 
/dev/mapper/vg_share-home /share/home xfs defaults,usrquota,grpquota 0 0
/dev/mapper/vg_share-project /share/projects xfs defaults,usrquota,grpquota 0 0

xfs_quota -x -c "quota enable" /share/home
xfs_quota -x -c "state" /share/home
xfs_quota -x -c "limit bsoft=15m bhard=20m ipa1" /share/home
xfs_quota -x -c "report -h" /share/home
# new user default
xfs_quota -x -c "limit -d bsoft=15m bhard=20m" /share/home
```

``` example
[root@head ~]# xfs_quota -x -c "report -h" /share/home
User quota on /share/home (/dev/mapper/vg_share-home)
                        Blocks              
User ID      Used   Soft   Hard Warn/Grace   
---------- --------------------------------- 
root            0    15M    20M  00 [------]
ipa1        15.5M    15M    20M  00 [7 days]
ipa2          20K    15M    20M  00 [------]
ipa3          20K    15M    20M  00 [------]
ipa4         476K    15M    20M  00 [------]
ipa5          16K    15M    20M  00 [------]

<!-- The user has 7 days to reduce usage before they are completely blocked from writing new data -->

[ipa1@head ~]$ fallocate -l 7M testfile2
fallocate: fallocate failed: Disk quota exceeded
```

``` bash
# Assigning Quotas - not working
# edquota -u username
# edquota -g groupname
# # Enabling Quotas
# quotaon -v /share/home
# generate a report on all quotas
# repquota /share/home

# Verifying Quotas
quota -u username
quota -g groupname
## [root@com1 ~]# quota -u ipa1
# Disk quotas for user ipa1 (uid 737000003): 
#      Filesystem  blocks   quota   limit   grace   files   quota   limit   grace
# 10.10.10.130:/share/home
#                   15860*  15360   20480   6days      26       0       0 
```

[REF: du](https://cyberpanel.net/blog/check-size-of-the-directory-in-linux)
``` bash
# check folder size
du -sh  ../ipa1
# if=data-source
dd if=/dev/zero of=testfile bs=1M count=10
# Allocates 10MB of disk space without writing zeroes.
fallocate -l 10M testfile
```

sudoer on freeIPA [tutorial](https://www.freeipa.org/page/Howto/HBAC_and_allow_all)
------

``` bash
# Check if you have a valid Kerberos ticket:
klist
kinit admin
#### enable allow_sudo(Sudoer) , allow_ssh(Passwordless) using UI
# ipa hbacrule-disable allow_all
# ipa hbacrule-show allow_all
# ipa hbacrule-find
# # ipa sudorule-find
# ipa hbacrule-show allow_sudo
# ipa sudorule-show ipa-sudo
# ipa group-show groupsudo
sudo rm -rf /var/lib/sss/db/*
sudo systemctl restart sssd
[ipa3@com1 ~]$ sudo -l
[sudo] password for ipa3: 
Matching Defaults entries for ipa3 on com1:
    !visiblepw, always_set_home, match_group_by_gid, always_query_group_plugin,
    env_reset, env_keep="COLORS DISPLAY HOSTNAME HISTSIZE KDEDIR LS_COLORS",
    env_keep+="MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE",
    env_keep+="LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES",
    env_keep+="LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE",
    env_keep+="LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY",
    secure_path=/sbin\:/bin\:/usr/sbin\:/usr/bin

User ipa3 may run the following commands on com1:
    (%groupsudo, admin : groupsudo) ALL
```

Grafana, Prometheus, node-exporter [tutorial](https://ozwizard.medium.com/how-to-install-and-configure-prometheus-grafana-on-rhel9-a23085992e6e)
------

##### Grafana

``` bash
wget -q -O gpg.key https://rpm.grafana.com/gpg.key

sudo rpm --import gpg.key
nano /etc/yum.repos.d/grafana.repo
```

/etc/yum.repos.d/grafana.repo

``` txt
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
exclude=*beta*
```

``` bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
yum install grafana
systemctl enable grafana-server
systemctl start grafana-server
systemctl status grafana-server
# port 3000,default username and password admin
# grafana-cli admin reset-admin-password admin
```

##### Prometheus

Add user prometheus with shell /sbin/nologin

``` bash
mkdir /var/lib/prometheus

# Creating necessary directories under etc

for i in rules rules.d files_sd; do
    sudo mkdir -p /etc/prometheus/${i};
done

# Switching to the opt directory.
cd /opt

# Downloading Prometheus as a compressed file.
wget https://github.com/prometheus/prometheus/releases/download/v2.37.9/prometheus-2.37.9.linux-arm64.tar.gz

# Extracting the compressed file.
tar -xzvf prometheus-2.37.9.linux-arm64.tar.gz

cd prometheus-2.37.9.linux-arm64

# Moving required files for the service.
cp prometheus promtool /usr/local/bin/

# Creating necessary files and directories under etc.
cp -r prometheus.yml consoles/ console_libraries/ /etc/prometheus/

nano /etc/systemd/system/prometheus.service

# set the target
vi /etc/prometheus/prometheus.yml 
```

/etc/systemd/system/prometheus.service

``` txt
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
```

``` bash
chown -R prometheus:prometheus /etc/prometheus
chmod -R 775 /etc/prometheus/
chown -R prometheus:prometheus /var/lib/prometheus/

systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus
```

##### node-exporter [tutorial](https://rm-rf.medium.com/install-node-exporter-for-prometheus-grafana-d0ec29b8a2b6)

At head

``` bash
vi /opt/prometheus-2.37.9.linux-arm64/prometheus.yml
systemctl restart prometheus.service

```

``` txt
    static_configs:
      - targets: ["head:9090", "com1:9100"]
```

At com

``` bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-arm64.tar.gz
tar -xf node_exporter-1.5.0.linux-arm64.tar.gz
sudo mv node_exporter-1.5.0.linux-arm64/node_exporter /usr/local/bin
rm -r node_exporter-1.5.0.linux-arm64*
sudo useradd -rs /bin/false node_exporter
vi /etc/systemd/system/node_exporter.service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
sudo firewall-cmd --permanent --add-port=9100/tcp
sudo firewall-cmd --reload
```

/etc/systemd/system/node_exporter.service

``` txt
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

[References](https://jhooq.com/prometheous-grafan-setup/)

NFS access control list [youtube](https://www.youtube.com/watch?v=rvZ35YW4t5k)
------

At head

``` bash
getfacl /share/home/
setfacl -x d:u:ipa3 /share/home
setfacl -d -m "ipa3:rwx" /share/home/lab2_test/

setfacl -R -m "manager:rwx" /share/projects
```

At client

``` bash
dnf install nfs4-acl-tools
nfs4_getfacl /share/home
# Example 1: Give User ipa1 Full Permissions
nfs4_setfacl -a "A::ipa1@ipa.test:rwx" /share/home
# Clear all ACLs
nfs4_setfacl -c /share/home
# Remove john's write access:
nfs4_setfacl -x "A::ipa1@ipa.test" /mnt/nfs/home
```

```bash
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
```

Projects structure

``` bash
# root
mkdir 02_lecture
chown -R lecturer:lecturer 02_lecture
setfacl -R -m g:lecturer:rwx 02_lecture
setfacl -R -m d:g:lecturer:rwx 02_lecture
# lecture(ipa2)
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
```

> References:
> 1. https://learn.microsoft.com/en-us/azure/azure-netapp-files/nfs-access-control-lists

Commands
------

``` bash
systemctl stop sssd ; rm -rf /var/lib/sss/db/* ; systemctl restart sssd
```