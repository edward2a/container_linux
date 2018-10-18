#!/bin/bash
set -euo pipefail

SCRIPT=CL-Setup
APT_OPTS="--no-install-recommends"

function die(){
    logger -p user.error -t ${SCRIPT} $1
    echo "ERROR: $1"
    exit 1
}

function install_fluentbit(){
    curl -s https://packages.fluentbit.io/fluentbit.key | apt-key add -
    echo "deb http://packages.fluentbit.io/ubuntu xenial main" > /etc/apt/sources.list.d/fluentbit.list
    apt-get update
    apt-get install ${APT_OPTS} td-agent-bit

    # file input db cache location
    mkdir /var/cache/td-agent-bit
}

function configure_rsyslog(){

    # Use syslog protocol 23 (similar to RFC5424)
    sed -i -e 's/^\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat/$ActionFileDefaultTemplate RSYSLOG_SyslogProtocol23Format/' /etc/rsyslog.conf

    if grep -q '$ActionFileDefaultTemplate RSYSLOG_SyslogProtocol23Format' /etc/rsyslog.conf; then
        return 0
    else
        echo "ERROR: failed to configure rsyslogd!"
        return 1
    fi
}


# MAIN
install_fluentbit
configure_rsyslog
