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
}


# MAIN
install_fluentbit
