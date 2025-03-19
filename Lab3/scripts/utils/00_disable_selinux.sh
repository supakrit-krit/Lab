#!/bin/bash

echo "Disabling SELinux..."
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config