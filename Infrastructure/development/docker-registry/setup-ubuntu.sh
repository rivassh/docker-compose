#!/bin/bash
set -eo pipefail

sudo apt update

# install docker engine and docker-compose
sudo snap install docker
docker --version
docker compose version

# create a directory for the registry
cd ~
mkdir -p ./registry/data

# install htpasswd
sudo apt install apache2-utils
# create a password file - set REGISTRY_USERNAME and REGISTRY_PASSWORD env vars before running
htpasswd -Bbn "${REGISTRY_USERNAME:?Set REGISTRY_USERNAME}" "${REGISTRY_PASSWORD:?Set REGISTRY_PASSWORD}" > ./registry/registry.password

# put your certificate and key in the certs directory
mkdir -p ./nginx/certs
