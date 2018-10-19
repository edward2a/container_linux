#!/bin/bash
set -euo pipefail

SCRIPT=CL-Setup
APT_OPTS="--no-install-recommends"
SCRIPT_DIR=$(dirname $0)


function die() {
    logger -p user.error -t ${SCRIPT} $1
    echo "ERROR: $1"
    exit 1
}


function ubuntu_setup() {

    local removal

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
        unattended-upgrades
    )

    apt-get remove -qq --purge ${removal[*]}

    # dnsmasq/resolvconf removal fix for resolv.conf
    if ifconfig eth0 &>/dev/null; then
        dhclient eth0
    else
        dhclient ens5
    fi
    ping -c1 -qn www.google.com &>/dev/null

    # system upgrade to date
    apt-get update
    apt-get -qq dist-upgrade

}


function install_fluentbit() {
    curl -s https://packages.fluentbit.io/fluentbit.key | apt-key add -
    echo "deb http://packages.fluentbit.io/ubuntu xenial main" > /etc/apt/sources.list.d/fluentbit.list
    apt-get update
    apt-get install ${APT_OPTS} td-agent-bit

    # file input db cache location
    mkdir /var/cache/td-agent-bit

    systemctl enable td-agent-bit

}


function configure_rsyslog() {

    # Use syslog protocol 23 (similar to RFC5424)
    sed -i -e 's/^\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat/$ActionFileDefaultTemplate RSYSLOG_SyslogProtocol23Format/' /etc/rsyslog.conf

    if grep -q '$ActionFileDefaultTemplate RSYSLOG_SyslogProtocol23Format' /etc/rsyslog.conf; then
        return 0
    else
        echo "ERROR: failed to configure rsyslogd!"
        return 1
    fi
}


function install_set_hostname() {

    # Disable cloudinit's hostname config
    sed -i -e 's/^preserve_hostname: false$/preserve_hostname: true/' /etc/cloud/cloud.cfg

    if grep -q '^preserve_hostname: true$' /etc/cloud/cloud.cfg; then
        return 0
    else
        echo "ERROR: failed to disable cloudinit's hostname config"
        return 1
    fi

    install -m 755 -o root -g root -D ${SCRIPT_DIR}/set_hostname/set_hostname.sh /usr/local/bin/
    install -m 644 -o root -g root -D ${SCRIPT_DIR}/set_hostname/set_hostname.service /lib/systemd/system/

    systemctl enable set_hostname

}


function install_docker() {

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get -qq install docker-ce

    DOCKER_CREDS="${SCRIPT_DIR}/docker.login"
    if [ -f ${DOCKER_CREDS} ]; then
        source ${DOCKER_CREDS}
        docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${DOCKER_REGISTRY}
    fi

    systemctl enable docker

}


function install_container_linux() {

    install -m 755 -o root -g root -D ${SCRIPT_DIR}/container_linux/container_linux_init.sh /usr/local/bin
    install -m 644 -o root -g root -D ${SCRIPT_DIR}/container_linux/container_linux.service /lib/systemd/system/
    systemctl daemon-reload
    systemctl enable container_linux

}


function final_cleanup() {
    truncate --size=0 /var/log/syslog /var/log/*.log
    rm -f /home/ubuntu/.ssh/authorized_keys /root/authorized_keys
    apt-get clean && apt-get -qq autoremove --purge
}


# MAIN
ubuntu_setup
install_fluentbit
configure_rsyslog
install_set_hostname
install_docker
install_container_linux
final_cleanup
