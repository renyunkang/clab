#!/bin/bash
set -v

#name="simple"
name="openelb-secip"
clab destroy -t clab.yaml 
kind delete cluster --name=${name}
