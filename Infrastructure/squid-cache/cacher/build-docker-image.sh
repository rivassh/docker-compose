#!/bin/sh
set -e

DOCKER_ACC=hipod
DOCKER_REPO=squid-ubuntu
IMG_TAG=latest

docker login --username="$DOCKER_USERNAME" --password="$DOCKER_PASSWORD"
docker build -t $DOCKER_ACC/$DOCKER_REPO:$IMG_TAG .
docker push $DOCKER_ACC/$DOCKER_REPO:$IMG_TAG
