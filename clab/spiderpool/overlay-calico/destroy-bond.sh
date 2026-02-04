#!/bin/bash
set -v

name="bond"
clab destroy -t clab-bond.yaml 
kind delete cluster --name=${name}
