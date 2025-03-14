Lab2: HPC
=========

Requirements
------

- /home: 100G thin LVM share
- ssh passwordless: public key authen
- nfs quota
- nfs access control list
- sudoer on freeIPA
- Grafana, Prometheus, node-exporter
- Notify
- HPC Architecture
    - Head node
        - FreeIPA        - NFS Server
        - 2 Network (public, private)
    - Compute node
        - only private network

Head Node (192.168.30.141): head:lab2password
    - Having FreeIPA, NFS Server

LVM
------

Q: [Thick and Thin Provisioning: What Is the Difference?](https://www.nakivo.com/blog/thick-and-thin-provisioning-difference/)

- Thick provisioning is a type of storage pre-allocation. With thick provisioning, the complete amount of virtual disk storage capacity is pre-allocated on the physical storage when the virtual disk is created. A thick-provisioned virtual disk consumes all the space allocated to it in the datastore right from the start, so the space is unavailable for use by other virtual machines.

- Thin provisioning is another type of storage pre-allocation. A thin-provisioned virtual disk consumes only the space that it needs initially, and grows with time according to demand. For example, if you create a new thin-provisioned 30GB virtual disk and copy 10 GB of files to it, the size of the resulting VMDK file will be 10 GB, whereas you would have a 30GB VMDK file if you had chosen to use a thick-provisioned disk.


>Reference: 
>1.	https://datarecoverylab.wordpress.com/2010/05/09/hard-drive-bus-types-scsi-sata-esata-ide-sas-and-firewire-ieee-1394/


Create LVM
------

``` bash
# Create LVM with NVMe thin disk 100G
echo "Setting up LVM on NVMe disk..."
pvcreate /dev/nvme0n2
vgcreate vg_home /dev/nvme0n2
lvcreate -L 10G -T vg_home/thinpool
lvcreate -V 10G -T vg_home/thinpool -n lv_home
mkfs.xfs /dev/vg_home/lv_home
mkdir -p /share/home
mount /dev/vg_home/lv_home /share/home
```

Grafana, Prometheus, node-exporter [tutorial](https://ozwizard.medium.com/how-to-install-and-configure-prometheus-grafana-on-rhel9-a23085992e6e)
------

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
```

Prometheus

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

NFS quota (TODO)
------

``` bash
dnf install quota quotatool -y

```

SSH passwordless: public key authen [tutorial](https://www.informaticar.net/password-less-authetication-on-centos-red-hat/)
------

At host

``` bash
ssh-keygen -t rsa -C ipa1@ipa.test
# put in FreeIPA
cat ~/.ssh/id_rsa_lab2_ipa1.pub
chmod 600 ~/.ssh/id_rsa_lab2_ipa1
# using ssh -v ipa1@head for verbose
.ssh % ssh -i ~/.ssh/id_rsa_lab2 ipa1@head
# if done ~/.ssh/config config
ssh ipa1
```

~/.ssh/config

``` txt
Host ipa1
	HostName head.ipa.test
	User ipa1
	IdentityFile ~/.ssh/id_rsa_lab2_ipa1
	IdentitiesOnly yes

Host ipa2
        HostName head.ipa.test
        User ipa2
        IdentityFile ~/.ssh/id_rsa_lab2_ipa2
	IdentitiesOnly yes

```
