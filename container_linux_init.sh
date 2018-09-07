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
    # containerVars='-e VERBOSE=false'
    # containerVarSeparator=';'
    # loggingDriver=fluentd
    # loggingEndpoint=logz.example.com#
    # loggingOptions="--log-opt fluentd-address=${loggingEndpoint}"

    eval $(/usr/bin/ec2metadata --user-data)
}

function configureLogging(){
    # sed -i -e "s//${loggingEndpoint}/"
    echo
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
        docker rm -f ${imageName##*/}_${imageTag}
    fi
}

function processPorts(){
    for port in ${containerPorts//,/ }; do echo -n "-p $port "; done
}

function processVariables(){
    local IFS
    IFS="${containerVarSeparator:-;}"
    for var in ${containerVars}; do echo -n "-e ${var}"; done
}

function startContainer(){
    docker run -d \
        --log-driver=${loggingDriver} \
        --log-opt mode=non-blocking \
        --log-opt max-buffer-size=32m \
        ${loggingOptions} \
        $(processPorts) \
        ${containerOptions} \
        "$(processVariables)" \
        --name ${imageName##*/}_${imageTag} \
        ${imageName}:${imageTag} || \
        die "Failed to start container."
}


## MAIN
checkUser
getUserData
configureLogging
registryLogin
pullContainer
checkOldContainer
startContainer


