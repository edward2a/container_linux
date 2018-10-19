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

    echo "INFO: Executing Ubuntu System Setup"

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

    echo "INFO: Executing FluentBit Install"

    curl -s https://packages.fluentbit.io/fluentbit.key | apt-key add -
    echo "deb http://packages.fluentbit.io/ubuntu xenial main" > /etc/apt/sources.list.d/fluentbit.list
    apt-get update
    apt-get install ${APT_OPTS} td-agent-bit

    # file input db cache location
    mkdir /var/cache/td-agent-bit

    # configure and install boot time output updater
    bash ${SCRIPT_DIR}/fluentd/config_td_agent.sh
    install -v -m 755 -o root -g root -D ${SCRIPT_DIR}/fluentd/fluentbit_output.sh /usr/local/bin/
    install -v -m 644 -o root -g root -D ${SCRIPT_DIR}/fluentd/fluentbit_output.service /lib/systemd/system/
    install -v -m 644 -o root -g root -D ${SCRIPT_DIR}/fluentd/logrotate/container_logs /etc/logrotate.d/


    systemctl daemon-reload
    systemctl enable td-agent-bit
    systemctl enable fluentbit_output


}


function configure_rsyslog() {

    echo "INFO: Executing RSysLog Config"

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

    echo "INFO: Executing Set-Hostname Install"

    # Disable cloudinit's hostname config
    sed -i -e 's/^preserve_hostname: false$/preserve_hostname: true/' /etc/cloud/cloud.cfg

    if ! grep -q '^preserve_hostname: true$' /etc/cloud/cloud.cfg; then
        echo "ERROR: failed to disable cloudinit's hostname config"
        return 1
    fi

    install -v -m 755 -o root -g root -D ${SCRIPT_DIR}/set_hostname/set_hostname.sh /usr/local/bin/
    install -v -m 644 -o root -g root -D ${SCRIPT_DIR}/set_hostname/set_hostname.service /lib/systemd/system/

    systemctl daemon-reload
    systemctl enable set_hostname

}


function install_docker() {

    echo "INFO: Executing Docker Install"

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get -qq install docker-ce

    DOCKER_CREDS="${SCRIPT_DIR}/docker.login"
    if [ -f ${DOCKER_CREDS} ]; then
        source ${DOCKER_CREDS}
        docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${DOCKER_REGISTRY}
    fi

    systemctl daemon-reload
    systemctl enable docker

}


function install_container_linux() {

    echo "INFO: Executing Container-Linux Install"

    install -v -m 755 -o root -g root -D ${SCRIPT_DIR}/container_linux/container_linux_init.sh /usr/local/bin
    install -v -m 644 -o root -g root -D ${SCRIPT_DIR}/container_linux/container_linux.service /lib/systemd/system/

    systemctl daemon-reload
    systemctl enable container_linux

}


function final_cleanup() {

    echo "INFO: Execufing Final Cleanup"

    rm -f /home/ubuntu/.ssh/authorized_keys /root/authorized_keys
    apt-get clean && apt-get -qq autoremove --purge
    truncate --size=0 /var/log/syslog /var/log/*.log

}


# MAIN
ubuntu_setup
install_fluentbit
configure_rsyslog
install_set_hostname
install_docker
install_container_linux
final_cleanup
