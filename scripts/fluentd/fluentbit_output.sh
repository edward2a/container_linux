#!/bin/bash
set -e

eval $(ec2metadata --user-data)
if [ -n "${loggingEndpoint}" ]; then
    sed -i -r -e "/^\[OUTPUT\]$/, \${ /\s+Host.*$/ s/Host.*$/Host ${loggingEndpoint}/g }" /etc/td-agent-bit/td-agent-bit.conf
fi
