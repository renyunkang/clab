#!/bin/bash
set -v

name="openelb-mulcidr"
clab destroy -t clab.yaml 
kind delete cluster --name=${name}
