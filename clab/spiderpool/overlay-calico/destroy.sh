#!/bin/bash
set -v

name="spiderpool"
clab destroy -t clab.yaml 
kind delete cluster --name=${name}
