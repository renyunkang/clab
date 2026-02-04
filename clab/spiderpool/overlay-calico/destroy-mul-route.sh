#!/bin/bash
set -v

#name="simple"
name="spider-mul"
clab destroy -t clab-mul-route.yaml 
kind delete cluster --name=${name}
