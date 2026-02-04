#!/bin/bash
set -v

#name="simple"
name="multus"
clab destroy -t clab.yaml 
kind delete cluster --name=${name}
