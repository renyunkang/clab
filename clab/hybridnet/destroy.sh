#!/bin/bash
set -v

name="hybridnet"
clab destroy -t clab.yaml 
kind delete cluster --name=${name}
