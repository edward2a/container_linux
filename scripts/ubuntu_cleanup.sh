#!/bin/bash

removal=(
    command-not-found
    command-not-found-data
    python3-commandnotfound
    dnsmasq
    resolvconf
    lxd
    lxd-client
    liblxc1
    lxc-common
    lxcfs
    mlocate
    nano
    ntfs-3g
    open-iscsi
    open-vm-tools
    pastebinit
    popularity-contest
    python3-distupgrade
    snapd
    sosreport
    ubuntu-core-launcher
    ufw
)

apt-get remove -qq --purge ${removal[*]}
