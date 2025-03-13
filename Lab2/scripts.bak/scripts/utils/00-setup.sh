#!/bin/bash

# Ensure the script runs as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Starting setup..."

# Execute scripts in order
for script in ./01-disable-selinux.sh \
               ./02-setup-lvm.sh \
               ./03-configure-network.sh \
               ./04-install-nfs.sh \
               ./05-install-freeipa.sh \
               ./06-configure-firewall.sh \
               ./07-final-checks.sh
do
  if [ -f "$script" ]; then
    echo "Running $script..."
    bash "$script"
    if [ $? -ne 0 ]; then
      echo "Error encountered in $script. Exiting!"
      exit 1
    fi
  else
    echo "Script $script not found! Skipping..."
  fi
done

echo "Setup complete!"
