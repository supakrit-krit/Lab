Lab4: Bonding
=========

Requirements
------

- tmux
- forward mail -> google, smtp
- grafana
  - in transit
  - y:nodes x:time
- bonding: Network interface -> port 
  - NIC teaming
  - protocol: active backup
  - expectation: LACP

- 2 head nodes -> 1 virtual IP

``` txt
com1 192.168.1.169 10.10.10.128
head 192.168.1.170 10.10.10.129
com2 192.168.1.171 10.10.10.130
head2 192.168.1.173 10.10.10.131

VIP: 10.10.10.100

local:lab3password
```

Reset
------

``` bash
sudo systemctl stop postfix
sudo systemctl disable postfix
sudo systemctl stop dovecot
sudo systemctl disable dovecot
sudo dnf remove postfix dovecot -y
sudo rm -rf /etc/postfix
sudo rm -rf /etc/dovecot
sudo rm -rf /var/spool/postfix
sudo rm -rf /var/lib/dovecot
sudo rm -rf /etc/ssl/private
sudo rm -rf /etc/ssl/certs/mailserver.crt
sudo userdel alertmanager-smtpuser
sudo userdel smtpuser
sudo rm -rf /home/alertmanager-smtpuser /home/smtpuser

# reset prmetheus
rm -rf /var/lib/prometheus/*
```

On transit
------

vi /etc/prometheus/rules/node_exporter.yaml 

``` bash
groups:
  - name: node_exporter
    interval: 15s
    rules:
      - alert: NodeDown
        expr: changes(up[1m]) > 0 and up == 0
        labels:
          severity: warning
        annotations:
          summary: 'Instance {{ $labels.instance }} down'
          description: 'The instance {{ $labels.instance }} has changed within the last 1 minute.'

      - alert: NodeUp
        expr: changes(up[1m]) > 0 and up == 1
        labels:
          severity: info
        annotations:
          summary: 'Instance {{ $labels.instance }} up'
          description: 'The instance {{ $labels.instance }} has change within the last 1 minute.'
```

Forward to google
------

vi /etc/alertmanager/alertmanager.yml 

``` bash
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.gmail.com:587' # e.g., smtp.yourdomain.com:587
  smtp_from: 'supakrit.krit.work@gmail.com'
  smtp_auth_username: 'supakrit.krit.work@gmail.com'
  smtp_auth_password: 'uvsmwdfwjuzqxoug'
  smtp_require_tls: true

route:
     group_by: ['alertname']
     group_wait: 10s
     group_interval: 5s
     repeat_interval: 1h
     receiver: 'gmail-notifications'

receivers:
  - name: 'gmail-notifications'
    email_configs:
      - to: 'supakrit.krit.work@gmail.com'
        from: 'supakrit.krit.work@gmail.com'
        send_resolved: false

inhibit_rules:
  - source_match:
      serverity: 'critical'
    target_match:
      serverity: 'warning'
    equal: ['alertname', 'instance']
```

NodeUp Dashboard
------

``` txt
count(up{job="node_exporter"} == 1)
```

Chrony
------

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

Bonding mode=1
------

``` bash
sudo dnf install -y NetworkManager teamd keepalived
```

head (master)

``` bash
sudo nmcli connection add type bond con-name bond0 ifname bond0 mode active-backup
sudo nmcli connection add type ethernet con-name slave-ens256 ifname ens256 master bond0
sudo nmcli connection add type ethernet con-name slave-ens161 ifname ens161 master bond0
sudo nmcli connection modify bond0 ipv4.method manual ipv4.addresses 10.10.10.129/24
sudo nmcli connection up bond0
```

head2 (backup)

``` bash
sudo nmcli connection add type bond con-name bond0 ifname bond0 mode active-backup
sudo nmcli connection add type ethernet con-name slave-ens256 ifname ens256 master bond0
sudo nmcli connection add type ethernet con-name slave-ens161 ifname ens161 master bond0
sudo nmcli connection modify bond0 ipv4.method manual ipv4.addresses 10.10.10.131/24
sudo nmcli connection up bond0
```

vi /etc/keepalived/keepalived.conf

head (master)

``` txt
vrrp_instance VI_1 {
    state MASTER
    interface bond0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    unicast_src_ip 10.10.10.129
    unicast_peer {
        10.10.10.131
    }
    virtual_ipaddress {
        10.10.10.100
    }
}
```

head2 (backup)

``` txt
vrrp_instance VI_1 {
    state BACKUP
    interface bond0
    virtual_router_id 51
    priority 90
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    unicast_src_ip 10.10.10.131
    unicast_peer {
        10.10.10.129
    }
    virtual_ipaddress {
        10.10.10.100
    }
}
```

test

``` bash
cat /proc/net/bonding/bond0
sudo ip link set ens161 down
sudo ip link set ens161 up
systemctl stop keepalived
```

Fix FreeIPA

on head (primary)

``` bash
ipa-replica-prepare head2.ipa.test

```

on head2 (replica)

``` bash
ipa-client-install \
  --hostname=head2.ipa.test \
  --mkhomedir \
  --server=head.ipa.test \
  --domain=ipa.test \
  --realm=IPA.TEST \
  --principal=admin \
  --password=lab3password \
  --enable-dns-updates -U

ipa-replica-install

# Fix passwordless tiket expire > crontab
kinit <username>
crontab -e
# minute hour day month day-of-week
0 * * * * /root/kinit_all_users.sh
```


Commands
------

``` bash
systemctl stop sssd ; rm -rf /var/lib/sss/db/* ; systemctl restart sssd
```