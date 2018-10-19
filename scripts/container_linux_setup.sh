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

function install_fluentbit() {
    curl -s https://packages.fluentbit.io/fluentbit.key | apt-key add -
    echo "deb http://packages.fluentbit.io/ubuntu xenial main" > /etc/apt/sources.list.d/fluentbit.list
    apt-get update
    apt-get install ${APT_OPTS} td-agent-bit

    # file input db cache location
    mkdir /var/cache/td-agent-bit
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
}

function install_docker() {

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get -qq install docker-ce

    DOCKER_CREDS="$(dirname $0)/docker.login"
    if [ -f ${DOCKER_CREDS} ]; then
        source ${DOCKER_CREDS}
        docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${DOCKER_REGISTRY}
    fi
}

# MAIN
install_fluentbit
configure_rsyslog
install_set_hostname
install_docker
