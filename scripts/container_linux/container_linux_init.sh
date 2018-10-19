#!/bin/bash
set -euo pipefail

SCRIPT=CL-Init

function die(){
    logger -p user.error -t ${SCRIPT} $1
    echo "ERROR: $1"
    exit 1
}

function checkUser() {
    [[ ${UID} == 0 ]] || die "Invocation by non-root user"
}

function getUserData(){
    # Expected user-data model:
    #
    # registryLogin=false
    # registryUrl=null
    # registryUser=null
    # registryPassword=null
    # imageName=nginx
    # imageTag=mainline-alpine
    # containerOptions='--net=host'
    # containerPorts='80:80'
    # containerVars=VERBOSE=false\;STDOUT=true
    # containerVarSeparator=';'
    # loggingEndpoint=logz.example.com#

    eval $(/usr/bin/ec2metadata --user-data)
}

function registryLogin(){
    if [[ ${registryLogin} == 'true' ]]; then
        docker login -u ${registryUser} -p ${registryPassword} ${registryUrl}
    fi
}

function pullContainer(){
    docker pull ${imageName}:${imageTag} || die "Failed to pull container ${imageName}:${imageTag}"
}

function checkOldContainer(){
    if $(docker ps -a -f "name=${imageName##*/}_${imageTag}" --format "{{.Names}}" | grep -q ${imageName##*/}_${imageTag}); then
        docker rm -v -f ${imageName##*/}_${imageTag}
    fi
}

function processPorts(){
    for port in ${containerPorts//,/ }; do echo -n "-p $port "; done
}

function processVariables(){
    local IFS
    IFS="${containerVarSeparator:-;}"
    for var in ${containerVars}; do echo -n "-e '${var}' "; done
}

function startContainer(){
    eval `echo docker run -d \
        --log-driver=fluentd \
        --log-opt fluentd-address=127.0.0.1:24225 \
        --log-opt fluentd-async-connect=true \
        --log-opt fluentd-buffer-limit=32m \
        --log-opt fluentd-max-retries=60 \
        --log-opt fluentd-sub-second-precision=true \
        --log-opt mode=non-blocking \
        --log-opt max-buffer-size=32m \
        --log-opt tag="c_id.{{.ID}}" \
        $(processPorts) \
        ${containerOptions} \
        $(processVariables) \
        --name ${imageName##*/}_${imageTag} \
        ${imageName}:${imageTag}` || \
        die "Failed to start container."
}


## MAIN
checkUser
getUserData
registryLogin
pullContainer
checkOldContainer
startContainer


