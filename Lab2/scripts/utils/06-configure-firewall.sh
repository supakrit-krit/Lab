#!/bin/bash

echo "Configuring firewall rules..."

# NFS Services
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd

# FreeIPA Services
firewall-cmd --permanent --add-service=freeipa-ldap
firewall-cmd --permanent --add-service=freeipa-ldaps
firewall-cmd --permanent --add-service=freeipa-replication
firewall-cmd --permanent --add-service=dns

firewall-cmd --reload
echo "Firewall configuration complete."
