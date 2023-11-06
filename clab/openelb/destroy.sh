#!/bin/bash
set -v

name="openelb"
kind delete cluster --name=${name}
clab destroy -t clab.yaml
