#!/bin/sh
docker run -d --restart=always -p 3128:3128 hipod/squid-ubuntu:latest
