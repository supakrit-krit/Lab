#!/bin/bash
echo "Setting hostname..."
hostnamectl set-hostname head.ipa.test

read -p "Head node IP: " HEAD_IP
echo "${HEAD_IP} head.ipa.test head" >> /etc/hosts

read -p "How many compute nodes? " NODES

for ((i=1; i<=NODES; i++)); do
    read -p "Compute node #$i name: " COM_NAME
    read -p "Compute node #$i IP: " COM_IP
    echo "${COM_IP} ${COM_NAME}.ipa.test ${COM_NAME}" >> /etc/hosts
done

echo "All compute nodes added successfully!"
cat /etc/hosts
