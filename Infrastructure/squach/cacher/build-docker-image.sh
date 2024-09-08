#!/bin/sh
username='hipod';
password='';
docker login --username="$username" --password=""
DOCKER_ACC=hipod
#DOCKER_REPO=squid-3.5.12-1ubuntu7
DOCKER_REPO=squid-ubuntu
IMG_TAG=latest

docker build -t $DOCKER_ACC/$DOCKER_REPO:$IMG_TAG .
docker push $DOCKER_ACC/$DOCKER_REPO:$IMG_TAG
