Lab3: Grafana
=========

Requirements
------

- Dashboard: 
  - prometheus: alert rule -> any option (gmail,..)
  TODO
  - grafana: x:time, y:node amount

``` txt
com1 192.168.1.169 10.10.10.128
head 192.168.1.170 10.10.10.129
com2 192.168.1.171 10.10.10.130

local:lab3password
```

Grafana, Prometheus, node-exporter [tutorial](https://ozwizard.medium.com/how-to-install-and-configure-prometheus-grafana-on-rhel9-a23085992e6e)
------

##### Grafana

``` bash
wget -q -O gpg.key https://rpm.grafana.com/gpg.key
rpm --import gpg.key
vi /etc/yum.repos.d/grafana.repo
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
firewall-cmd --permanent --add-port=3000/tcp
firewall-cmd --reload
yum install grafana -y
systemctl enable --now grafana-server
systemctl status grafana-server
# port 3000,default username and password admin
# grafana-cli admin reset-admin-password admin
```

##### Prometheus

``` bash
useradd -M -r -s /bin/false prometheus
mkdir /etc/prometheus /var/lib/prometheus
mkdir /data/
cd /data/
wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-arm64.tar.gz
tar xvf prometheus-2.52.0.linux-arm64.tar.gz
cd prometheus-2.52.0.linux-arm64/
cp prometheus promtool /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/{prometheus,promtool}
cp -r {consoles,console_libraries}  /etc/prometheus/
cp prometheus.yml /etc/prometheus/
chown -R prometheus:prometheus /etc/prometheus
chown prometheus:prometheus /var/lib/prometheus
cat <<EOF>> /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Time Series Collection and Processing Server
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
 --config.file /etc/prometheus/prometheus.yml \
 --storage.tsdb.path /var/lib/prometheus/ \
 --web.console.templates=/etc/prometheus/consoles \
 --web.console.libraries=/etc/prometheus/console_libraries
[Install]
WantedBy=multi-user.target
EOF
```

``` bash
systemctl daemon-reload
systemctl enable --now prometheus
systemctl status prometheus
```

##### node-exporter [tutorial](https://github.com/anishrana2001/Prometheus/blob/main/03%20NodeExporter/Lab.md)

``` bash
useradd -M -r -s /bin/false node_exporter
mkdir /data
cd /data
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-arm64.tar.gz
tar xzf node_exporter-1.8.1.linux-arm64.tar.gz
cd node_exporter-1.8.1.linux-arm64/
cp node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
cat <<EOF>> /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
[Install]
WantedBy=multi-user.target
EOF
```

``` bash
systemctl daemon-reload
systemctl enable --now node_exporter
firewall-cmd --permanent --add-port=9100/tcp
firewall-cmd --reload
systemctl status node_exporter
```

``` bash
### at head node
vi /etc/prometheus/prometheus.yml
-----------------

scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: "node-exporter"                 # Added
    static_configs:                           # Added
      - targets: ["head:9100","com1:9100","com2:9100"]        # Added
```

``` bash
# Reload the Prometheus config:
sudo killall -HUP prometheus
```

Alertmanager
------

``` bash
useradd -M -r -s /bin/false alertmanager
mkdir /data
cd /data
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-arm64.tar.gz
tar xvzf alertmanager-0.27.0.linux-arm64.tar.gz 
cd alertmanager-0.27.0.linux-arm64/
cp alertmanager amtool /usr/local/bin/
chown alertmanager:alertmanager /usr/local/bin/{alertmanager,amtool}
mkdir -p /etc/alertmanager
cp alertmanager.yml /etc/alertmanager/
chown -R alertmanager:alertmanager /etc/alertmanager
mkdir -p /var/lib/alertmanager
chown alertmanager:alertmanager /var/lib/alertmanager
mkdir -p /etc/amtool
cat <<EOF>> /etc/amtool/config.yml
alertmanager.url: http://localhost:9093
EOF
cat <<EOF>> /etc/systemd/system/alertmanager.service
[Unit]
Description=Prometheus Alertmanager
Wants=network-online.target
After=network-online.target
[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager  --config.file /etc/alertmanager/alertmanager.yml  --storage.path /var/lib/alertmanager/
[Install]
WantedBy=multi-user.target
EOF
```

Alertmanager-smtpuser

Create a User and Set the Password. We will create 2 users, first user "alertmanager-smtpuser" will send the alerts through email and 2nd user "smtpuser" will receive the email notifications.

``` bash
# echo "DOMAINNAME=ipa.test" >> /etc/sysconfig/network
# echo "kernel.domainname = ipa.test" >> /etc/sysctl.conf
# dnsdomainname
adduser alertmanager-smtpuser
echo "lab3password" | passwd "alertmanager-smtpuser" --stdin
adduser smtpuser
echo "lab3password" | passwd "smtpuser" --stdin
dnf install postfix cyrus-sasl-lib libsasl2* -y
systemctl enable --now postfix
systemctl status postfix
dnf install dovecot -y
systemctl enable --now dovecot
systemctl status dovecot
mv /etc/postfix/main.cf /etc/postfix/main.cf.back
ip_subnet="10.10.10.0/24"
sudo tee -a /etc/postfix/main.cf > /dev/null <<EOF
myhostname = $(hostname -f)
mydomain = $(hostname -d)
myorigin = \$mydomain
inet_interfaces = all
inet_protocols = all
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 10.10.10.0/24, 127.0.0.0/8
home_mailbox = Maildir/
smtpd_banner = $myhostname ESMTP 
EOF
systemctl restart postfix
```

``` bash
mkdir /etc/ssl/private/
chmod 700 /etc/ssl/private/
cd /etc/ssl/private/
openssl genrsa -out /etc/ssl/private/ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/C=IN/ST=NEWDELHI/L=DEL/O=example, Inc./CN=example Root CA" -out /etc/ssl/private/ca.crt
openssl req -newkey rsa:2048 -nodes -keyout /etc/ssl/private/mailserver.key  -subj "/C=IN/ST=NEWDELHI/L=DEL/O=example, Inc./CN=*.example Root CA"  -out /etc/ssl/private/server.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:example.com,DNS:workernode1.example.com") -days 365 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out /etc/ssl/certs/mailserver.crt
```

``` bash
mv /etc/postfix/main.cf /etc/postfix/main.cf.back1
sudo tee -a /etc/postfix/main.cf > /dev/null <<EOF
myhostname = $(hostname -f)
mydomain = $(hostname -d)
myorigin = \$mydomain
inet_interfaces = all
inet_protocols = all
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 10.10.10.0/24, 127.0.0.0/8
home_mailbox = Maildir/
smtpd_banner = $myhostname ESMTP 

# Additional STARTTLS configuration settings
tls_random_source=dev:/dev/urandom

# SMTPD TLS configuration for incoming connections
smtpd_use_tls = yes
smtpd_tls_cert_file = /etc/ssl/certs/mailserver.crt
smtpd_tls_key_file = /etc/ssl/private/mailserver.key
smtpd_tls_security_level = may
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_local_domain =
smtpd_sasl_auth_enable = yes
smtpd_recipient_restrictions = noanonymous
#smtpd_recipient_restrictions = permit_sasl_authenticated, reject_unauth_destination
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination



# SMTP TLS configuration for outgoing connections
smtp_use_tls = yes
smtp_tls_cert_file = /etc/ssl/certs/mailserver.crt
smtp_tls_key_file = /etc/ssl/private/mailserver.key
smtp_tls_security_level = may
EOF
```

``` bash
sed -i 's/\#submission/submission/' /etc/postfix/master.cf
vi /etc/postfix/master.cf
```

``` txt
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=$mua_client_restrictions
  -o smtpd_helo_restrictions=$mua_helo_restrictions
  -o smtpd_sender_restrictions=$mua_sender_restrictions
  -o smtpd_recipient_restrictions=
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```

``` bash
vi /etc/dovecot/dovecot.conf
# listen = * # uncomment
vi /etc/dovecot/conf.d/10-auth.conf
# disable_plaintext_auth = no # uncomment
# auth_mechanisms = plain login # uncomment
vi /etc/dovecot/conf.d/10-mail.conf
# mail_location = maildir:~/Maildir # uncomment
vi /etc/dovecot/conf.d/10-master.conf
# # Postfix smtp-auth # uncomment
# unix_listener /var/spool/postfix/private/auth {
#   mode = 0666
#   user = postfix
#   group = postfix
# }
vi /etc/dovecot/conf.d/10-ssl.conf
# ssl = yes
systemctl restart dovecot
```

```
vi /etc/alertmanager/alertmanager.yml

global:
  resolve_timeout: 10m
  smtp_require_tls: true
route:
     group_by: ['alertname']
     group_wait: 10s
     group_interval: 10s
     repeat_interval: 10s
     receiver: 'email-notifications'
     routes:
     - receiver: 'email-notifications'
       continue: true                                              ## Added
     - receiver: 'email-notifications-gmail'                       ## Added
       continue: true                                              ## Added
receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'alertmanager-smtpuser@ipa.test'
        from: 'smtpuser@ipa.test'
        smarthost: 'head.ipa.test:587'
        auth_username: 'alertmanager-smtpuser'
        auth_identity: 'alertmanager-smtpuser'
        auth_password: 'lab3password'
  - name: 'email-notifications-gmail'                              ## Added
    email_configs:                                                 ## Added
      - to: supakrit.krit.work@gmail.com                              ## Added
        from: supakrit.krit.work@gmail.com                            ## Added
        smarthost: smtp.gmail.com:587                              ## Added
        auth_username: supakrit.krit.work@gmail.com                   ## Added
        auth_identity: supakrit.krit.work@gmail.com                   ## Added
        auth_password: uvsmwdfwjuzqxoug      ## Added 
```

``` bash
systemctl enable --now alertmanager
firewall-cmd --permanent --add-port=9093/tcp
firewall-cmd --reload
systemctl status alertmanager
```

``` bash
mkdir -p /etc/prometheus/rules
cd /etc/prometheus/rules
vi global_rule.yaml
vi /etc/prometheus/prometheus.yml
vi /etc/prometheus/rules/alert.yaml
vi /etc/prometheus/rules/node_exporter.yaml
```

vi global_rule.yaml

``` txt
groups:
 - name: nginx_server
   interval: 15s
   rules:
   - record: recording_rule_node_cpu_seconds_total_5m
     expr: (rate(node_cpu_seconds_total{job="node-exporter",mode="user",instance="192.168.1.31:9100"}[5m]))
```

vi /etc/prometheus/prometheus.yml

``` txt
# my global config
global:
  scrape_interval: 15s 
  evaluation_interval: 15s 
# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  - "/etc/prometheus/rules/*"      ## Added
```

vi /etc/prometheus/rules/alert.yaml

``` txt
groups:
 - name: nginx_server
   interval: 15s
   rules:
     - alert: node_manager_cpu_5m    # The name of the alert. Must be a valid label value.
       expr: sum((rate(node_cpu_seconds_total{job="node-exporter",mode="user",instance="192.168.1.31:9100"}[5m]))) > 0
       for: 10m                      # Alerts are considered firing once they have been returned for this long. Alerts which have not yet fired for long enough are considered pending. default = 0s
       keep_firing_for: 0s           # How long an alert will continue firing after the condition that triggered it has cleared. default = 0s
       labels:                       # Labels to add or overwrite for each alert.
          severity: critical
       annotations:                  # Annotations to add to each alert.
          description: node_manager
     - alert: HostOutOfMemory
       expr: node_memory_MemAvailable_bytes{instance="192.168.1.31:9100"} / node_memory_MemTotal_bytes{instance="192.168.1.31:9100"}  * 100 > 10
       for: 2m
       labels:
         severity: warning
       annotations:
         summary: "Host out of memory instance 192.168.1.31 : sevirity=warning"
         description: Node memory is filling up 
     - alert: HostMemoryUnderMemoryPressure
       expr: rate(node_vmstat_pgmajfault[1m]) > 1000
       for: 2m
       labels:
          severity: warning
       annotations:
          summary: Host memory under memory pressure (instance {{ $labels.instance }})
          description: "The node is under heavy memory pressure. High rate of major page faults\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"
```

vi /etc/prometheus/rules/node_exporter.yaml

``` txt
groups:
 - name: node_exporter                # Name of the group
   interval: 15s
   rules:
     - alert: NodeExporterServiceDown         # Name of the alert
       expr: up{job="node-exporter"} == 0     # == 0 means node_exporter service is down and 1 means up.
       labels:                                # We can also set the labels and we 
         severity: warning
       annotations:
         summary: Server is down
```

``` bash
### at head node
vi /etc/prometheus/prometheus.yml
-----------------

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["head:9093","com1:9093","com2:9093"]    # added only

# Check the Prometheus config syntax
promtool check config /etc/prometheus/prometheus.yml
killall -HUP prometheus
# claer previous data

systemctl restart prometheus
```

``` bash
# at M213
sudo systemsetup -getnetworktimeserver

sudo timedatectl set-timezone Asia/Bangkok

chronyc sources -v
# if com1.ipa.test chronyd[881]: Detected falseticker
vi /etc/chrony.conf # at server
server time.google.com iburst
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
allow 10.10.10.0/24
local stratum 2
# at client
server head iburst

chronyc sources -v
Reference ID    : 0A0A0A82 (head.ipa.test)

local stratum 10

sudo systemctl restart chronyd
sudo systemctl enable chronyd
```


HW

- tmux
- forward mail -> google, smtp
- grafana y:nodes x:time
- bonding: Network interface -> port 
  - NIC teaming
  - protocol: active backup
  - expectation: LACP

- 2 head nodes -> 1 virtual IP
