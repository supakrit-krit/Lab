#!/bin/bash

echo "Installing FreeIPA server..."
dnf install -y freeipa-server freeipa-server-dns

hostnamectl set-hostname head.ipa.test
echo "127.0.0.1 head.ipa.test" >> /etc/hosts

ipa-server-install \
  --realm=IPA.TEST \
  --domain=ipa.test \
  --hostname=head.ipa.test \
  --setup-dns \
  --auto-forwarders \
  --mkhomedir \
  -p 'lab2password' \
  -a 'lab2password' -U

echo "FreeIPA server installation complete."
