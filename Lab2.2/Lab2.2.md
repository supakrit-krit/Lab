Lab2.1: HPC Add
=========

Requirements
------

- Dashboard: 
  - prometheus: alert rule -> any option (gmail,..)
  - grafana: x:time, y:node
- nfs quota: enable
- nfs access control list:
  - non-root setting
  - apply quota

Head Node (192.168.30.142): head:lab2password
    - Having FreeIPA, NFS Server

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
mkdir -p /share/projects/{.backup,01_quickShare,02_lecture,03_team1,04_team2,99_Archived}
mkdir -p /share/projects/.backup/{2503_projectName1,2503_projectName2}
mkdir -p /share/projects/01_quickShare/{2503_projectName1,2503_projectName2}
mkdir -p /share/projects/02_lecture/{2503_projectName1,2503_projectName2}
mkdir -p /share/projects/03_team1/{2503_projectName1,2503_projectName2,9999_Archived}
mkdir -p /share/projects/04_team2/{2503_projectName1,2503_projectName2,9999_Archived}

# Allow team1 full access to 03_team1
setfacl -m g:team1:rwx /share/projects/03_team1
setfacl -R -m g:team1:rwx /share/projects/03_team1/*

# Allow team2 full access to 04_team2
setfacl -m g:team2:rwx /share/projects/04_team2
setfacl -R -m g:team2:rwx /share/projects/04_team2/*

# Allow backup team full access to .backup
setfacl -m g:groupsudo:rwx /share/projects/.backup
setfacl -R -m g:groupsudo:rwx /share/projects/.backup/*

# Allow lecture team access to 02_lecture
setfacl -m g:lecture:rx /share/projects/02_lecture
setfacl -R -m g:lecture:rx /share/projects/02_lecture/*

# Allow everyone read/write access to 01_quickShare
setfacl -m o:rwx /share/projects/01_quickShare
setfacl -R -m o:rwx /share/projects/01_quickShare/*

```

Projects structure

``` bash
# root
mkdir 02_lecture
chown -R root:lecture 02_lecture
setfacl -R -m g:lecture:rwx 02_lecture
setfacl -R -m d:g:lecture:rwx 02_lecture
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
# starter
setfacl -m g:starter_lecture:r-x 02_lecture/01_introduction
setfacl -m g:starter_lecture:r-x 02_lecture/02_basic
# --
setfacl -m g:starter_lecture:0 02_lecture/03_intermediate
setfacl -m g:starter_lecture:0 02_lecture/04_advance
setfacl -m g:starter_lecture:0 02_lecture/05_expert
# worker
setfacl -m g:starter_lecture:r-x 02_lecture/01_introduction
setfacl -m g:starter_lecture:r-x 02_lecture/02_basic
setfacl -m g:starter_lecture:r-x 02_lecture/03_intermediate
setfacl -m g:starter_lecture:r-x 02_lecture/04_advance
# --
setfacl -m g:worker_lecture:0 02_lecture/05_expert
# instructor
setfacl -m g:starter_lecture:r-x 02_lecture/01_introduction
setfacl -m g:starter_lecture:r-x 02_lecture/02_basic
setfacl -m g:starter_lecture:r-x 02_lecture/03_intermediate
setfacl -m g:starter_lecture:r-x 02_lecture/04_advance
setfacl -m g:starter_lecture:r-x 02_lecture/05_expert
```

> References:
> 1. https://learn.microsoft.com/en-us/azure/azure-netapp-files/nfs-access-control-lists

Commands
------

``` bash
systemctl stop sssd ; rm -rf /var/lib/sss/db/* ; systemctl restart sssd
```