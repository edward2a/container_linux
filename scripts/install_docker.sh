#!/bin/bash

apt-get update
apt-get -qq install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get -qq install docker-ce

DOCKER_CREDS="$(dirname $0)/docker.login"
if [ -f ${DOCKER_CREDS} ]; then
    source ${DOCKER_CREDS}
    docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${DOCKER_REGISTRY}
fi
