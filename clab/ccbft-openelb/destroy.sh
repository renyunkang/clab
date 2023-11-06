#!/bin/bash
set -v

name="openelb"
kind delete cluster --name=${name}
docker stop frr-upstream && docker rm frr-upstream
ip r del 10.10.100.0/24 via 172.20.0.5
