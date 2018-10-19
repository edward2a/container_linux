#!/bin/bash

## Function begin
function new_td_config() {

cat<<EOF >/etc/td-agent-bit/td-agent-bit.conf
[SERVICE]
    Flush        5
    Daemon       Off
    Log_Level    info
    Parsers_File parsers.conf
    Plugins_File plugins.conf
    HTTP_Server  Off
    HTTP_Listen  0.0.0.0
    HTTP_Port    2020

EOF

## Function end
}

## Function begin
function add_td_syslog_file_input() {

cat<<EOF >>/etc/td-agent-bit/td-agent-bit.conf
[INPUT]
    Name tail
    Parser syslog-rfc5424
    Path /var/log/syslog
    Path_Key path
    Buffer_Chunk_Size 64k
    Buffer_Max_Size 128k
    Mem_Buf_Limit 32m
    DB /var/cache/td-agent-bit/syslog.db
    DB.Sync Normal

EOF

## Function end
}

## Function begin
function add_td_auth_file_input() {

cat<<EOF >>/etc/td-agent-bit/td-agent-bit.conf
[INPUT]
    Name tail
    Parser syslog-rfc5424
    Path /var/log/auth.log
    Path_Key path
    Buffer_Chunk_Size 32k
    Mem_Buf_Limit 8m
    DB /var/cache/td-agent-bit/auth-log.db
    DB.Sync Normal

EOF

## Function end
}

## Function begin
function add_td_cont_linux_journal_input() {

cat<<EOF >>/etc/td-agent-bit/td-agent-bit.conf
[INPUT]
    Name systemd
    Tag container-linux
    Systemd_Filter _SYSTEMD_UNIT=container-linux.service
    DB /var/cache/td-agent-bit/container-linux.db

EOF

## Function end
}

## Function begin
function add_td_fwd_input() {

cat<<EOF >>/etc/td-agent-bit/td-agent-bit.conf
[INPUT]
    Name forward
    Listen 127.0.0.1
    Port 24225
    Buffer_Max_Size 128k
    Buffer_Chunk_Size 32k

EOF

## Function end
}

## Function begin
function add_filter_hostname_key() {

cat<<EOF >>/etc/td-agent-bit/td-agent-bit.conf
[FILTER]
    Name record_modifier
    Match **
    Record hostname \${HOSTNAME}

EOF

## Function end
}

## Function begin
function add_td_fwd_output() {

local TargetForwarder
if [ -n "$1" ]; then
    TargetForwarder=$1
else
    TargetForwarder="127.0.0.1"
    echo "WARN: No fluentd forward endpoint defined, using ${TargetForwarder}"
fi

cat<<EOF >>/etc/td-agent-bit/td-agent-bit.conf
[OUTPUT]
    Name forward
    Match **
    Host ${TargetForwarder}
    Port 24224
    #Shared_Key Som3R4nd0mExampl3key
    tls off

EOF

## Function end
}


## Function begin
function add_container_log_file_output() {

cat<<EOF >>/etc/td-agent-bit/td-agent-bit.conf
[OUTPUT]
    # TODO update path to dynamic model https://github.com/fluent/fluent-bit/issues/604
    Name file
    Match c_id.*
    Path /var/log/containers.log

EOF

## Function end
}


# main
eval $(ec2metadata --user-data)
new_td_config
add_td_syslog_file_input
add_td_auth_file_input
add_td_cont_linux_journal_input
add_td_fwd_input
add_filter_hostname_key
add_td_fwd_output ${loggingEndpoint}
add_container_log_file_output

