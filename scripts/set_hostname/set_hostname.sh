#!/bin/sh
set -eux

NEW_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

hostname ${NEW_HOSTNAME}
echo ${NEW_HOSTNAME} > /etc/hostname
sed -i -e "s/^127.0.0.1 .*$/127.0.0.1 ${NEW_HOSTNAME} localhost/" /etc/hosts

