#!/bin/bash
set -v

name="noderr"
kind delete cluster --name=${name}
clab destroy -t clab.yaml
