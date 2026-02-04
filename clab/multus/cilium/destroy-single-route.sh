#!/bin/bash
set -v

#name="simple"
name="mul-single"
clab destroy -t clab-single.yaml 
kind delete cluster --name=${name}
